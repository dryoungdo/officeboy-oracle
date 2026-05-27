#!/usr/bin/env bash
# codex-pr-body.sh - render a PR-body audit trail from codex-review runs.log.

set -u

usage() {
  cat <<'EOF'
Usage: scripts/codex-pr-body.sh <repo-abs-path> [branch-name]

Writes markdown to stdout. Missing or empty review logs are non-fatal so PR
creation can continue.
EOF
}

repo_arg="${1:-}"
if [ -z "$repo_arg" ]; then
  usage >&2
  exit 2
fi

if ! repo_abs="$(cd "$repo_arg" 2>/dev/null && pwd -P)"; then
  printf '## Codex Review Audit Trail\n\n'
  printf 'No audit trail available. Repo path not found: `%s`.\n' "$repo_arg"
  exit 0
fi

branch="${2:-}"
if [ -z "$branch" ]; then
  branch="$(git -C "$repo_abs" branch --show-current 2>/dev/null || true)"
  [ -n "$branch" ] || branch="unknown"
fi

runs_log="${CODEX_REVIEW_RUNS_LOG:-${HOME}/.claude/.codex-review/runs.log}"
review_since="${CODEX_REVIEW_SINCE:-}"
cycle_gap_seconds="${CODEX_REVIEW_CYCLE_GAP_SECONDS:-1800}"
stale_after_seconds="${CODEX_REVIEW_STALE_AFTER_SECONDS:-86400}"

if [ ! -f "$runs_log" ]; then
  printf '## Codex Review Audit Trail\n\n'
  printf 'No audit trail available.\n'
  exit 0
fi

if ! python3 - "$repo_abs" "$branch" "$runs_log" "$review_since" "$cycle_gap_seconds" "$stale_after_seconds" <<'PY'
from datetime import datetime, timezone
import json
import os
import sys

repo_abs = sys.argv[1].rstrip("/")
repo_norm = os.path.realpath(repo_abs).rstrip("/")
branch = sys.argv[2]
runs_log = sys.argv[3]
review_since = sys.argv[4]
cycle_gap_seconds = int(sys.argv[5])
stale_after_seconds = int(sys.argv[6])


def is_same_or_child(value: str, root: str) -> bool:
    return value == root or value.startswith(root + "/")


def matches_repo(entry_repo: object) -> bool:
    if not isinstance(entry_repo, str) or not entry_repo:
        return False
    entry = entry_repo.rstrip("/")
    entry_norm = os.path.realpath(entry).rstrip("/")
    return is_same_or_child(entry, repo_abs) or is_same_or_child(entry_norm, repo_norm)


def md_cell(value: object) -> str:
    text = "" if value is None else str(value)
    return text.replace("\n", " ").replace("\r", " ").replace("|", "\\|")


def parse_ts(value: object):
    if not isinstance(value, str) or not value:
        return None
    text = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


since_dt = parse_ts(review_since)
if review_since and since_dt is None:
    print("## Codex Review Audit Trail")
    print()
    print(f"Repo: `{repo_abs}`")
    print(f"Branch: `{branch}`")
    print()
    print(f"No audit trail available. Invalid CODEX_REVIEW_SINCE value: `{md_cell(review_since)}`.")
    sys.exit(0)

entries = []
with open(runs_log, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if matches_repo(entry.get("repo")):
            entry["_parsed_ts"] = parse_ts(entry.get("ts"))
            entries.append(entry)

entries.sort(key=lambda item: (item.get("_parsed_ts") or datetime.min.replace(tzinfo=timezone.utc), str(item.get("ts", ""))))

window_label = ""
if since_dt is not None:
    entries = [
        entry
        for entry in entries
        if entry.get("_parsed_ts") is not None and entry["_parsed_ts"] >= since_dt
    ]
    window_label = f"since `{review_since}`"
elif entries:
    parsed_entries = [entry for entry in entries if entry.get("_parsed_ts") is not None]
    if parsed_entries:
        latest = parsed_entries[-1]["_parsed_ts"]
        now = datetime.now(timezone.utc)
        if (now - latest).total_seconds() > stale_after_seconds:
            entries = []
            window_label = f"latest matching run is older than {stale_after_seconds}s"
        else:
            start_index = len(entries) - 1
            while start_index > 0:
                current_ts = entries[start_index].get("_parsed_ts")
                previous_ts = entries[start_index - 1].get("_parsed_ts")
                if current_ts is None or previous_ts is None:
                    break
                gap = (current_ts - previous_ts).total_seconds()
                if gap > cycle_gap_seconds:
                    break
                start_index -= 1
            entries = entries[start_index:]
            window_label = f"latest run cluster (gap <= {cycle_gap_seconds}s)"
    else:
        window_label = "all matching runs (timestamps unavailable)"

print("## Codex Review Audit Trail")
print()
print(f"Repo: `{repo_abs}`")
print(f"Branch: `{branch}`")
if window_label:
    print(f"Window: {window_label}")
print()

if not entries:
    print("No matching codex review runs found in the selected window.")
    sys.exit(0)

print("| Pass | Status | Duration | Findings | Reason |")
print("|---|---|---:|---:|---|")

total_duration = 0
clean_streak = 0
for index, entry in enumerate(entries, start=1):
    status = str(entry.get("status", "unknown"))
    duration = entry.get("duration_s", 0)
    try:
        duration_int = int(duration)
    except (TypeError, ValueError):
        duration_int = 0
    total_duration += duration_int

    findings = entry.get("findings", 0)
    try:
        findings_int = int(findings)
    except (TypeError, ValueError):
        findings_int = 0

    reason = entry.get("reason", "")
    print(
        "| {pass_num} | {status} | {duration}s | {findings} | {reason} |".format(
            pass_num=index,
            status=md_cell(status),
            duration=duration_int,
            findings=findings_int,
            reason=md_cell(reason),
        )
    )

for entry in reversed(entries):
    if entry.get("status") == "clean":
        clean_streak += 1
    else:
        break

final_status = str(entries[-1].get("status", "unknown"))
within_iteration_cap = len(entries) <= 4
converged = clean_streak >= 2 and within_iteration_cap

print()
print(f"**Total review time**: {total_duration}s")
print(f"**Final state**: {md_cell(final_status)} ({clean_streak} consecutive clean passes)")
print(f"**Iteration cap**: {'ok' if within_iteration_cap else 'exceeded'} ({len(entries)}/4 passes)")
print(f"**Convergence**: {'yes' if converged else 'no'} ({len(entries)} passes)")
print()
print("Generated by `scripts/run-codex-review.sh`; raw log: `~/.claude/.codex-review/runs.log`.")
PY
then
  printf '## Codex Review Audit Trail\n\n'
  printf 'No audit trail available. Failed to parse `%s`.\n' "$runs_log"
fi

exit 0
