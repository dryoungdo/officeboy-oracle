#!/usr/bin/env bash
set -euo pipefail

ROOT="${OFFICEBOY_REPO:-$HOME/Code/github.com/dryoungdo/officeboy-oracle}"
MESSAGE="chore: save officeboy memory and config"
PUSH=1
YES=0

usage() {
  cat <<'EOF'
Usage: scripts/save-officeboy.sh [--yes] [--no-push] [--message "commit message"]

Reviewed save flow for OFFICEBOY memory/config.

Default mode shows the current state and exits without committing.
Use --yes only after Captain answers that the session should be saved as Git truth.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=1
      shift
      ;;
    --no-push)
      PUSH=0
      shift
      ;;
    --message|-m)
      MESSAGE="${2:?missing message}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$ROOT/.git" ]]; then
  printf 'not a git repo: %s\n' "$ROOT" >&2
  exit 1
fi

printf 'OFFICEBOY reviewed save\n'
printf 'Repo: %s\n\n' "$ROOT"

printf 'Current changes:\n'
git -C "$ROOT" status --short
printf '\n'

if [[ "$YES" -ne 1 ]]; then
  cat <<'EOF'
No commit was made.

Ask Captain:
"We created meaningful memory/config changes. Save this as Git truth now, checkpoint only, or review first?"

If Captain says yes, run:
  bash scripts/save-officeboy.sh --yes
EOF
  exit 0
fi

SAVE_PATHS=(
  "CLAUDE.md"
  "AGENTS.md"
  ".claude/settings.json"
  ".claude/settings.local.json"
  ".gitignore"
  "oracle-build"
  "scripts"
  "ψ/active"
  "ψ/inbox/glueboy"
  "ψ/inbox/handoff"
  "ψ/learn"
  "ψ/memory"
  "ψ/outbox"
  "ψ/reference"
)

is_reviewed_path() {
  local changed_path="$1"
  local reviewed_path
  for reviewed_path in "${SAVE_PATHS[@]}"; do
    if [[ "$changed_path" == "$reviewed_path" || "$changed_path" == "$reviewed_path/"* ]]; then
      return 0
    fi
  done
  return 1
}

changed_paths="$(
  {
    git -C "$ROOT" diff --name-only
    git -C "$ROOT" diff --cached --name-only
    git -C "$ROOT" ls-files --others --exclude-standard
  } | sort -u
)"
unreviewed_changes=""
while IFS= read -r changed_path; do
  [[ -z "$changed_path" ]] && continue
  if ! is_reviewed_path "$changed_path"; then
    unreviewed_changes+="${changed_path}"$'\n'
  fi
done <<<"$changed_paths"

if [[ -n "$unreviewed_changes" ]]; then
  printf '\nChanges outside reviewed OFFICEBOY save paths:\n%s\n' "$unreviewed_changes" >&2
  printf '\nRefusing to save automatically. Add the path to SAVE_PATHS or commit it manually after review.\n' >&2
  exit 1
fi

printf 'Staging reviewed OFFICEBOY memory/config paths...\n'
git -C "$ROOT" add -A -- "${SAVE_PATHS[@]}"

printf '\nStaged changes:\n'
git -C "$ROOT" diff --cached --name-status

if git -C "$ROOT" diff --cached --quiet; then
  printf '\nNo staged changes to commit.\n'
  exit 0
fi

printf '\nCommitting...\n'
git -C "$ROOT" commit -m "$MESSAGE"

if [[ "$PUSH" -eq 1 ]]; then
  printf '\nPushing...\n'
  git -C "$ROOT" push
else
  printf '\nPush skipped by --no-push.\n'
fi

printf '\nSaved as Git truth.\n'
