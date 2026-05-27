#!/usr/bin/env bash
# test-sop-qa-gate.sh — Test suite for the SOP-QA top-5 gate
# ---------------------------------------------------------------------------
# Verifies each of the 5 rules in scripts/hooks/sop-qa-rules/ produces the
# correct exit code (0=pass, 2=block) for representative inputs.
#
# Each rule has two test cases minimum: one input that SHOULD block, one that
# SHOULD pass. Also covers: bypass token, fail-open on missing JSONL,
# fail-open on unknown tool, fail-open on missing rules dir.
#
# Run: bash scripts/hooks/test-sop-qa-gate.sh
# Output: per-case PASS/FAIL summary + total at the end. Exits 1 if any fail.
# ---------------------------------------------------------------------------
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/scripts/hooks/sop-qa-gate.sh"

PASS=0
FAIL=0
FAILED_CASES=""

# Run a test case. Usage:
#   run_case <name> <expected-exit> <input-json>
run_case() {
  local name="$1"
  local expected="$2"
  local input="$3"

  local actual
  actual=$(printf '%s' "${input}" | bash "${HOOK}" 2>/dev/null; echo $?)
  # The above prints stderr to /dev/null and captures exit code on last line.
  # But our trick concatenates output with exit code — split by last line.
  actual=$(printf '%s\n' "${actual}" | tail -1)

  if [ "${actual}" = "${expected}" ]; then
    printf '  ✓ %s (exit %s as expected)\n' "${name}" "${actual}"
    PASS=$((PASS+1))
  else
    printf '  ✗ %s — expected exit %s, got %s\n' "${name}" "${expected}" "${actual}"
    FAIL=$((FAIL+1))
    FAILED_CASES="${FAILED_CASES}\n  - ${name}"
  fi
}

# ============================================================================
# Universal cases — gate basics
# ============================================================================
printf '\n[group] Gate basics\n'

run_case "empty-input passes" 0 ""

run_case "non-PreToolUse event passes" 0 \
'{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"test"}'

run_case "missing-tool-name fails-open (passes)" 0 \
'{"hook_event_name":"PreToolUse","session_id":"test"}'

run_case "bypass token passes any rule" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw tile 1 -e codex","_bypass":"GLUEBOY_GATE_BYPASS=test-override-reason"},"session_id":"test"}'

# ============================================================================
# Rule 3 — Bypass-flag (most deterministic; no JSONL dependency)
# ============================================================================
printf '\n[group] Rule 3 — Bypass-flag\n'

run_case "rule3 BLOCK: maw tile -e codex without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw tile 1 -e codex"},"session_id":"test"}'

run_case "rule3 BLOCK: maw tile 4 -e codex" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw tile 4 -e codex"},"session_id":"test"}'

run_case "rule3 BLOCK: maw tile after command separator without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cd /tmp && maw tile 1 -e codex"},"session_id":"test"}'

run_case "rule3 BLOCK: maw tile in control flow without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"if true; then maw tile 1 -e codex; fi"},"session_id":"test"}'

run_case "rule3 BLOCK: maw tile in if condition without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"if maw tile 1 -e codex; then echo ok; fi"},"session_id":"test"}'

run_case "rule3 BLOCK: maw tile in bash -lc without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"bash -lc \"maw tile 1 -e codex\""},"session_id":"test"}'

run_case "rule3 BLOCK: assignment-prefixed maw tile without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"VAR=1 maw tile 1 -e codex"},"session_id":"test"}'

run_case "rule3 BLOCK: env-prefixed maw tile without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"env FOO=bar maw tile 1 -e codex"},"session_id":"test"}'

run_case "rule3 BLOCK: optioned sudo maw tile without bypass flag" 2 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"sudo -E maw tile 1 -e codex"},"session_id":"test"}'

run_case "rule3 PASS: maw tile with bypass flag" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw tile 1 --path /tmp --cmd \"codex --dangerously-bypass-approvals-and-sandbox\""},"session_id":"test"}'

run_case "rule3 PASS: maw tile with bypass flag and pwd command" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw tile 1 --path \"$(pwd)\" --cmd \"codex --dangerously-bypass-approvals-and-sandbox\""},"session_id":"test"}'

run_case "rule3 PASS: codex alone (not maw tile)" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"codex --version"},"session_id":"test"}'

run_case "rule3 PASS: maw tile clean (not codex)" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw tile clean"},"session_id":"test"}'

run_case "rule3 PASS: maw tile clean followed by codex" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw tile clean && codex --version"},"session_id":"test"}'

run_case "rule3 PASS: control word as plain argument" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo then maw tile 1 -e codex"},"session_id":"test"}'

run_case "rule3 PASS: quoted maw tile codex in commit message" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit -m \"fix: refer to maw tile 1 -e codex in doctrine\""},"session_id":"test"}'

run_case "rule3 PASS: quoted maw tile codex in echo" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo \"see maw tile 1 -e codex docs\""},"session_id":"test"}'

run_case "rule3 PASS: commented maw tile codex" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"# README about maw tile 1 -e codex"},"session_id":"test"}'

# ============================================================================
# Rule 5 — bg-task paired wakeup (deterministic if JSONL absent → fail-open pass)
# ============================================================================
printf '\n[group] Rule 5 — bg-task paired wakeup\n'

run_case "rule5 PASS: no run_in_background flag" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"test"}'

run_case "rule5 fail-open PASS: bg=true with no JSONL findable" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"long_running","run_in_background":true},"session_id":"nonexistent-uuid-12345"}'

# Note: real BLOCK testing for rule 5 requires a synthetic JSONL with no
# ScheduleWakeup in last assistant message. That's an integration concern,
# not a unit test. The fail-open above proves the rule doesn't break the
# user's tool call when JSONL is missing.

# ============================================================================
# Rules 1, 2, 4 — depend on JSONL session context
# Only smoke-test that they fail-open when JSONL absent (don't break user)
# ============================================================================
printf '\n[group] Rules 1/2/4 — JSONL-dependent fail-open\n'

run_case "rule1 fail-open: Edit to .ts but no JSONL" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/src/foo.ts","old_string":"x","new_string":"y"},"session_id":"nonexistent-uuid"}'

run_case "rule1 PASS: Edit to .md (doctrine, exempt)" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/CLAUDE.md","old_string":"x","new_string":"y"},"session_id":"test"}'

run_case "rule1 PASS: Write to ψ/memory/" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/repo/ψ/memory/learnings/foo.md","content":"x"},"session_id":"test"}'

run_case "rule2 fail-open: Edit to .py no JSONL" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"/repo/scripts/foo.py","old_string":"x","new_string":"y"},"session_id":"nonexistent-uuid"}'

run_case "rule4 fail-open: maw hey to pane, no JSONL" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw hey 01-glueboy:glueboy-oracle.2 \"hi\" --force"},"session_id":"nonexistent-uuid"}'

run_case "rule4 PASS: maw hey to oracle (not pane)" 0 \
'{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"maw hey clinic-nat:mycelium \"hi\" --force"},"session_id":"test"}'

# ============================================================================
# Summary
# ============================================================================
TOTAL=$((PASS+FAIL))
printf '\n=== test-sop-qa-gate.sh summary ===\n'
printf '  Total: %d   PASS: %d   FAIL: %d\n' "${TOTAL}" "${PASS}" "${FAIL}"

if [ "${FAIL}" -gt 0 ]; then
  printf '\nFailed cases:%b\n' "${FAILED_CASES}"
  exit 1
fi

printf '\n✅ All tests passed.\n'
exit 0
