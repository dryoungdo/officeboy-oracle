# sop-qa-rules/04-pane-recheck.sh — Rule 4: pane re-check after kill
# ---------------------------------------------------------------------------
# After `maw kill` or `maw tile clean`, tmux can silently renumber panes.
# A later `maw hey <oracle>:<window>.<pane>` may target a stale address unless
# `maw panes` was run after the kill/clean to refresh the live layout.
#
# Surfaced as issue #46 on 2026-05-24: a stale pane index routed briefs to the
# wrong Codex tile after pane cleanup/re-spawn.
#
# Applies: PreToolUse Bash with `maw hey` targeting a numbered pane reference
# Check: scan recent Bash commands; block if the most recent kill/clean has no
#        newer `maw panes` command
# ---------------------------------------------------------------------------

sop_qa_rule_pane_recheck_applies() {
  [ "${SOP_QA_TOOL}" = "Bash" ] || return 1

  local command
  command="$(sop_qa_tool_input_field command)"
  [ -n "${command}" ] || return 1

  printf '%s' "${command}" | grep -qE 'maw[[:space:]]+hey' || return 1
  printf '%s' "${command}" | grep -qE 'maw[[:space:]]+hey[[:space:]]+[^ ]*[a-z-]+:[a-zA-Z0-9_-]+\.[0-9]+' || return 1

  return 0
}

sop_qa_rule_pane_recheck_check() {
  [ -z "${SOP_QA_JSONL:-}" ] && return 0  # fail-open
  [ ! -f "${SOP_QA_JSONL}" ] && return 0

  local saw_panes
  local status
  local command
  saw_panes=0

  sop_qa_recent_bash_commands 30 | while IFS= read -r command; do
    if printf '%s' "${command}" | grep -qE '(^|[[:space:];&|])maw[[:space:]]+panes([[:space:]]|$)'; then
      saw_panes=1
      continue
    fi

    if printf '%s' "${command}" | grep -qE '(^|[[:space:];&|])maw[[:space:]]+kill([[:space:]]|$)|(^|[[:space:];&|])maw[[:space:]]+tile[[:space:]]+clean([[:space:]]|$)'; then
      [ "${saw_panes}" = "1" ] && exit 0
      exit 1
    fi
  done
  status="$?"

  [ "${status}" = "0" ] && return 0

  sop_qa_emit_hint "pane-recheck" "Bash is sending \`maw hey\` to a numbered pane after a recent \`maw kill\` or \`maw tile clean\`, but no newer \`maw panes\` command was found in recent Bash history.

   Per issue #46:
   tmux silently renumbers surviving panes after kill/clean. Pane addresses held
   before cleanup may point at a different Codex tile.

   Run:
     maw panes

   Then resend the \`maw hey <oracle>:<window>.<pane>\` command using the verified address."
  return 1
}
