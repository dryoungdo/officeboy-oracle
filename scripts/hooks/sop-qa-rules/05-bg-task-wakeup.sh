# sop-qa-rules/05-bg-task-wakeup.sh — Rule 5: bg-task wakeup pairing
# ---------------------------------------------------------------------------
# When a Bash tool call sets `run_in_background: true`, a paired ScheduleWakeup
# call (or Monitor) MUST appear in the same assistant turn — otherwise a hung
# bg task produces no completion signal and the loop blocks indefinitely.
#
# Surfaced as Instance 9b of "act without verifying" 2026-05-24 (6h+ silent
# stall on Codex review hang). Doctrine in shared-claude.md.
#
# Applies: PreToolUse Bash with run_in_background=true
# Check: scan recent assistant turn for ScheduleWakeup tool_use; pass if found
# ---------------------------------------------------------------------------

sop_qa_rule_bg_task_wakeup_applies() {
  [ "${SOP_QA_TOOL}" = "Bash" ] || return 1
  # tool_input.run_in_background must be true
  printf '%s' "${SOP_QA_INPUT}" | grep -qE '"run_in_background"[[:space:]]*:[[:space:]]*true' || return 1
  return 0
}

sop_qa_rule_bg_task_wakeup_check() {
  # Look at the current assistant turn — does it include ScheduleWakeup OR a Monitor task?
  # The current Bash tool_use is in the SAME assistant turn we're hooking on. We look at
  # the most recent assistant message in the JSONL and check for ScheduleWakeup/Monitor.
  [ -z "${SOP_QA_JSONL:-}" ] && return 0  # fail-open
  [ ! -f "${SOP_QA_JSONL}" ] && return 0

  local has_paired
  has_paired=$(python3 - "${SOP_QA_JSONL}" <<'PY' 2>/dev/null || true
import json, sys
jsonl = sys.argv[1]
last_assistant = None
try:
    with open(jsonl, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                m = json.loads(line)
                if m.get('type') == 'assistant':
                    last_assistant = m
            except Exception:
                continue
except Exception:
    sys.exit(0)
if not last_assistant:
    print("0")
    sys.exit(0)
content = last_assistant.get('message', {}).get('content', [])
if not isinstance(content, list):
    print("0")
    sys.exit(0)
for c in content:
    if isinstance(c, dict) and c.get('type') == 'tool_use':
        name = c.get('name', '')
        if name == 'ScheduleWakeup' or name == 'Monitor':
            print("1")
            sys.exit(0)
print("0")
PY
)

  if [ "${has_paired}" = "1" ]; then
    return 0  # pass — paired wakeup found
  fi

  # No paired ScheduleWakeup. Block with hint.
  sop_qa_emit_hint "bg-task-wakeup" "Bash tool call has \`run_in_background: true\` but no paired \`ScheduleWakeup\` (or Monitor) in this assistant turn.

   Per shared-claude.md §\"Background tasks with hang risk\":
   The harness's bg-task completion notification fires ONLY on natural completion.
   Hangs produce NO signal. Without a wake-up timer, you wait indefinitely for a
   notification that never comes (Instance 9b 2026-05-24 caused a 6h+ stall).

   Pair with:
     ScheduleWakeup({
       delaySeconds: <1.5-2x your nominal runtime>,
       reason: \"<task> fallback — check progress, kill if frozen\",
       prompt: \"<re-enters the loop>\"
     })"
  return 1
}
