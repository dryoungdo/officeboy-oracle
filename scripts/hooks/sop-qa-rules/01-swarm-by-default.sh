# sop-qa-rules/01-swarm-by-default.sh — Rule 1: Swarm-by-Default strategy announcement
# ---------------------------------------------------------------------------
# Before Edit/Write touches source code, the assistant MUST have announced an
# upfront strategy: either STRATEGY: SOLO with justification, or STRATEGY: SWARM
# with delegation shape. This catches Instance 11 of solo drift under goal
# pressure before source files are changed.
#
# Applies: PreToolUse Edit/Write to source-code file paths
# Check: scan recent assistant lines for literal "STRATEGY:"; block if absent
# ---------------------------------------------------------------------------

sop_qa_rule_swarm_by_default_applies() {
  [ "${SOP_QA_TOOL}" = "Edit" ] || [ "${SOP_QA_TOOL}" = "Write" ] || return 1

  local file_path
  file_path="$(sop_qa_tool_input_field file_path)"
  [ -n "${file_path}" ] || return 1

  # Memory/active doctrine writes are not source-code edits for this rule.
  case "${file_path}" in
    ψ/memory/*|*/ψ/memory/*|ψ/active/*|*/ψ/active/*)
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

sop_qa_rule_swarm_by_default_check() {
  [ -z "${SOP_QA_JSONL:-}" ] && return 0  # fail-open
  [ ! -f "${SOP_QA_JSONL}" ] && return 0

  local recent_assistant
  recent_assistant="$(sop_qa_recent_assistant_lines 5 2>/dev/null || true)"

  if printf '%s\n' "${recent_assistant}" | grep -q 'STRATEGY:'; then
    return 0  # pass — strategy announcement found
  fi

  # No recent strategy announcement. Block with hint.
  sop_qa_emit_hint "swarm-by-default" "Edit/Write to source code requires an upfront Swarm-by-Default strategy announcement.

   Announce \`STRATEGY: SOLO\` or \`STRATEGY: SWARM\` before touching source files.
   Use SOLO only when the work is truly a single small slice; use SWARM when
   the task has independent file/feature concerns that should be delegated.

   Required examples:
     [codex/glueboy] STRATEGY: SOLO. Justification: single rule file implementation.
     [codex/glueboy] STRATEGY: SWARM. Justification: independent frontend/backend slices."
  return 1
}
