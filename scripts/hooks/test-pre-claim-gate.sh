#!/usr/bin/env bash
# test-pre-claim-gate.sh — regression test for pre-claim-gate.sh
# Feeds synthetic PreToolUse / PostToolUse JSON and asserts the gate's behavior.
# Run: bash scripts/hooks/test-pre-claim-gate.sh
set -u

HOOK="$(cd "$(dirname "$0")" && pwd)/pre-claim-gate.sh"
GATE_DIR="${HOME}/.claude/.pre-claim-gate"
S="test-gate-0000"
LEDGER="${GATE_DIR}/ledger-${S}"

# clean slate
rm -rf "${GATE_DIR}/mark-"* 2>/dev/null || true
rm -f  "${LEDGER}" 2>/dev/null || true

PASS=0; FAIL=0
check() { # name  expect_exit  actual_exit  expect_substr  actual_out
  local ok=1
  [ "$2" = "$3" ] || ok=0
  if [ -n "$4" ]; then printf '%s' "$5" | grep -qF "$4" || ok=0; fi
  if [ "${ok}" = 1 ]; then
    printf '  ok    %s (exit %s)\n' "$1" "$3"; PASS=$((PASS+1))
  else
    printf '  FAIL  %s — wanted exit %s + "%s", got exit %s\n' "$1" "$2" "$4" "$3"
    printf '        out: %s\n' "$(printf '%s' "$5" | head -1)"; FAIL=$((FAIL+1))
  fi
}
run()  { OUT="$(printf '%s' "$1" | bash "${HOOK}" 2>&1)"; RC=$?; }
pre()  { printf '{"hook_event_name":"PreToolUse","session_id":"%s","tool_name":"%s","tool_input":{"command":"%s"}}' "${S}" "$1" "$2"; }
post() { printf '{"hook_event_name":"PostToolUse","session_id":"%s","tool_name":"Bash","tool_input":{"command":"echo x"}}' "${S}"; }

echo "── pre-claim-gate regression test ──"

# 1 — routine command passes silently
run "$(pre Bash 'ls -la')";                          check "routine 'ls' passes"        0 "${RC}" "" "${OUT}"
# 2 — git push blocks the first time (EVIDENCE)
run "$(pre Bash 'git push origin testbranch')";      check "git push → BLOCK-1"          2 "${RC}" "push commits" "${OUT}"
# 3 — immediate re-issue, nothing ran → blocks again
run "$(pre Bash 'git push origin testbranch')";      check "re-issue, no check → BLOCK-2" 2 "${RC}" "still blocked" "${OUT}"
# 4 — PostToolUse appends to the ledger
run "$(post)";                                       check "PostToolUse → ledger append" 0 "${RC}" "" "${OUT}"
LL="$(wc -l < "${LEDGER}" 2>/dev/null | tr -d ' ')"
[ "${LL}" = "1" ] && { echo "  ok    ledger has 1 line"; PASS=$((PASS+1)); } \
                  || { echo "  FAIL  ledger line count = ${LL:-0}, wanted 1"; FAIL=$((FAIL+1)); }
# 5 — re-issue after a real tool ran + pause aged → PASS
sleep 4
run "$(pre Bash 'git push origin testbranch')";      check "re-issue after check → PASS" 0 "${RC}" "" "${OUT}"
# 6 — gh pr merge → ASK (Captain approval)
run "$(pre Bash 'gh pr merge 5')";                   check "gh pr merge → ASK"           0 "${RC}" '"permissionDecision":"ask"' "${OUT}"
# 6b — fly deploy → ASK (Codex P1 fix: 'fly' not 'flyctl?')
run "$(pre Bash 'fly deploy --remote-only')";        check "fly deploy → ASK"            0 "${RC}" '"permissionDecision":"ask"' "${OUT}"
# 6c — vercel --version should NOT be gated (Codex P3 word-boundary)
run "$(pre Bash 'vercel --version')";                check "vercel --version → PASS"     0 "${RC}" "" "${OUT}"
# 7 — maw broadcast blocks (EVIDENCE)
run "$(pre Bash 'maw hey clinic-nat:x hello')";      check "maw hey → BLOCK"             2 "${RC}" "broadcast to another Oracle" "${OUT}"
# 8 — malformed JSON with a risky keyword → FAIL-LOUD
run '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command": BROKEN git push}';
                                                     check "malformed+keyword → FAIL-LOUD" 2 "${RC}" "internal error" "${OUT}"
# 9 — explicit bypass token allows the action
run "$(pre Bash 'git push origin z # GLUEBOY_GATE_BYPASS=regression-test')";
                                                     check "bypass token → PASS"         0 "${RC}" "" "${OUT}"
# 10 — TeamCreate (fan-out) blocks
run '{"hook_event_name":"PreToolUse","session_id":"test-gate-0000","tool_name":"TeamCreate","tool_input":{"name":"t"}}';
                                                     check "TeamCreate → BLOCK"          2 "${RC}" "fan-out" "${OUT}"
# 11 — non-keyword Bash passes
run "$(pre Bash 'echo hello world')";                check "non-keyword Bash passes"     0 "${RC}" "" "${OUT}"
# 12 — gh pr create with 'gh pr merge' in body → EVIDENCE (was a real bug pre-v1.2)
run "$(pre Bash 'gh pr create --body fix-the-gh-pr-merge-bug')"; check "gh pr create w/ merge-in-body → EVIDENCE" 2 "${RC}" "open or comment on a pull request" "${OUT}"
# 13 — rtk-wrapped git push is still gated (wrapper unwrap)
run "$(pre Bash 'rtk git push origin x')";           check "rtk git push → EVIDENCE"     2 "${RC}" "push commits" "${OUT}"
# 14 — git -C <path> push is still gated
run "$(pre Bash 'git -C /tmp/x push origin feature')";check "git -C ... push → EVIDENCE" 2 "${RC}" "push commits" "${OUT}"
# 15 — git commit with risky-keyword bodies must NOT be gated (caused a fail-LOUD bug pre-v1.2)
run "$(pre Bash 'git add . && git commit -m fix-push-merge-deploy-bug')"; check "git commit w/ keywords in msg → PASS" 0 "${RC}" "" "${OUT}"

# cleanup
rm -rf "${GATE_DIR}/mark-"* 2>/dev/null || true
rm -f  "${LEDGER}" 2>/dev/null || true

echo "──────────────────────────────────"
echo "  ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ] || exit 1
