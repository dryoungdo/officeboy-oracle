# sop-qa-rules/02-issue-first.sh — Rule 2: issue-first source edits
# ---------------------------------------------------------------------------
# Source-code edits must be anchored to a GitHub issue before the first file
# write. This preserves a durable decision trail and keeps coding work tied to
# reviewable issue context instead of ad hoc terminal momentum.
#
# Applies: PreToolUse Edit/Write targeting source-code files
# Check: scan recent user/assistant text for a GitHub issue reference
# ---------------------------------------------------------------------------

sop_qa_rule_issue_first_applies() {
  case "${SOP_QA_TOOL}" in
    Edit|Write) ;;
    *) return 1 ;;
  esac

  local file_path
  file_path="$(sop_qa_tool_input_field file_path)"
  if [ -z "${file_path}" ]; then
    file_path="$(printf '%s' "${SOP_QA_INPUT:-}" | python3 -c 'import json, sys
try:
    obj = json.load(sys.stdin)
    val = obj.get("tool_input", {}).get("file_path", "")
    if isinstance(val, str):
        print(val)
except Exception:
    pass' 2>/dev/null || true)"
  fi
  [ -z "${file_path}" ] && return 1

  case "${file_path}" in
    CLAUDE.md|*/CLAUDE.md|AGENTS.md|*/AGENTS.md|oracle-build/*|*/oracle-build/*|ψ/*|*/ψ/*)
      return 1
      ;;
  esac

  case "${file_path}" in
    *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.sh|*.bash|*.rb|*.java|*.c|*.cpp|*.h|*.hpp)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sop_qa_rule_issue_first_check() {
  [ -z "${SOP_QA_JSONL:-}" ] && return 0  # fail-open
  [ ! -f "${SOP_QA_JSONL}" ] && return 0

  local recent_lines
  recent_lines="$(
    {
      sop_qa_recent_user_lines 10
      sop_qa_recent_assistant_lines 10
    } 2>/dev/null || true
  )"

  if printf '%s\n' "${recent_lines}" | grep -qE 'gh issue|#[0-9]+|Closes #'; then
    return 0
  fi

  sop_qa_emit_hint "issue-first" "Edit/Write targets a source-code file without a recent GitHub issue reference.

   Per Issue-First doctrine:
   Source-code changes need an issue anchor before editing, so the work has a
   durable decision trail and a review target.

   File or reference a GitHub issue first, then retry with one of:
     gh issue ...
     #57
     Closes #57"
  return 1
}
