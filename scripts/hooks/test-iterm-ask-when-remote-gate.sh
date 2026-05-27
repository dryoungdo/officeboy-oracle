#!/usr/bin/env bash
# test-iterm-ask-when-remote-gate.sh — verify the iTerm-ask gate
# ---------------------------------------------------------------------------
# 4 test cases:
#   1. PreToolUse + AskUserQuestion + last user msg from Discord → EXIT 2 (block)
#   2. PreToolUse + AskUserQuestion + last user msg from iTerm   → EXIT 0 (allow)
#   3. PreToolUse + Bash (different tool)                         → EXIT 0 (pass)
#   4. PostToolUse + AskUserQuestion                              → EXIT 0 (pass)
#   5. Bypass token in question text                              → EXIT 0 (bypass logged)
# ---------------------------------------------------------------------------
set -u

GATE="/Users/dr.dosmacstudio/ghq/github.com/dryoungdo/glueboy-oracle/scripts/hooks/iterm-ask-when-remote-gate.sh"
PROJECT_DIR="${HOME}/.claude/projects/test-iterm-ask-gate"
mkdir -p "${PROJECT_DIR}"

PASS=0
FAIL=0

assert_exit() {
  local case_name="$1"
  local expected="$2"
  local actual="$3"
  if [ "${expected}" = "${actual}" ]; then
    echo "  ✓ ${case_name}: exit ${actual}"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${case_name}: expected exit ${expected}, got ${actual}"
    FAIL=$((FAIL + 1))
  fi
}

# ===== Case 1: PreToolUse + AskUserQuestion + Discord =====
echo "Case 1 — Discord channel inbound → expect BLOCK (exit 2)"
SESSION_ID="test-discord-$(date +%s)"
JSONL="${PROJECT_DIR}/${SESSION_ID}.jsonl"
cat > "${JSONL}" <<'EOF'
{"type":"user","timestamp":"2026-05-24T03:00:00Z","message":{"role":"user","content":"<channel source=\"plugin:discord:discord\" chat_id=\"1502134305227407360\" message_id=\"x\" user=\"dr_youngdo\" ts=\"2026-05-24T03:00:00Z\">test question from Discord</channel>"}}
EOF

INPUT_JSON=$(cat <<JSON
{
  "hook_event_name": "PreToolUse",
  "tool_name": "AskUserQuestion",
  "session_id": "${SESSION_ID}",
  "tool_input": {
    "questions": [{"question": "Should I X or Y?", "header": "test", "options": [{"label": "X", "description": "do X"}, {"label": "Y", "description": "do Y"}]}]
  }
}
JSON
)

echo "${INPUT_JSON}" | bash "${GATE}" >/dev/null 2>/tmp/gate-test-1.err
ACTUAL=$?
assert_exit "Discord channel → block" "2" "${ACTUAL}"
# verify hint mentions the chat_id
if grep -q "1502134305227407360" /tmp/gate-test-1.err; then
  echo "  ✓ hint includes chat_id"
  PASS=$((PASS + 1))
else
  echo "  ✗ hint missing chat_id"
  FAIL=$((FAIL + 1))
fi

# ===== Case 2: PreToolUse + AskUserQuestion + iTerm =====
echo "Case 2 — iTerm input → expect ALLOW (exit 0)"
SESSION_ID="test-iterm-$(date +%s)"
JSONL="${PROJECT_DIR}/${SESSION_ID}.jsonl"
cat > "${JSONL}" <<'EOF'
{"type":"user","timestamp":"2026-05-24T03:00:00Z","message":{"role":"user","content":"hello, do the next step please"}}
EOF

INPUT_JSON=$(cat <<JSON
{
  "hook_event_name": "PreToolUse",
  "tool_name": "AskUserQuestion",
  "session_id": "${SESSION_ID}",
  "tool_input": {"questions": [{"question": "X?", "header": "h", "options": [{"label": "a", "description": "a"}, {"label": "b", "description": "b"}]}]}
}
JSON
)

echo "${INPUT_JSON}" | bash "${GATE}" >/dev/null 2>/dev/null
ACTUAL=$?
assert_exit "iTerm input → allow" "0" "${ACTUAL}"

# ===== Case 3: PreToolUse + Bash (different tool) =====
echo "Case 3 — Different tool (Bash) → expect PASS (exit 0)"
INPUT_JSON=$(cat <<JSON
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "session_id": "any",
  "tool_input": {"command": "ls"}
}
JSON
)

echo "${INPUT_JSON}" | bash "${GATE}" >/dev/null 2>/dev/null
ACTUAL=$?
assert_exit "Bash tool → pass-through" "0" "${ACTUAL}"

# ===== Case 4: PostToolUse — not the hook's event =====
echo "Case 4 — PostToolUse event → expect PASS (exit 0)"
INPUT_JSON=$(cat <<JSON
{
  "hook_event_name": "PostToolUse",
  "tool_name": "AskUserQuestion",
  "session_id": "any"
}
JSON
)

echo "${INPUT_JSON}" | bash "${GATE}" >/dev/null 2>/dev/null
ACTUAL=$?
assert_exit "PostToolUse event → pass-through" "0" "${ACTUAL}"

# ===== Case 5: Bypass token =====
echo "Case 5 — Bypass token in question → expect ALLOW (exit 0, logged as bypass)"
SESSION_ID="test-bypass-$(date +%s)"
JSONL="${PROJECT_DIR}/${SESSION_ID}.jsonl"
cat > "${JSONL}" <<'EOF'
{"type":"user","timestamp":"2026-05-24T03:00:00Z","message":{"role":"user","content":"<channel source=\"plugin:discord:discord\" chat_id=\"123\" user=\"x\" ts=\"x\">test</channel>"}}
EOF

INPUT_JSON=$(cat <<JSON
{
  "hook_event_name": "PreToolUse",
  "tool_name": "AskUserQuestion",
  "session_id": "${SESSION_ID}",
  "tool_input": {"questions": [{"question": "test GLUEBOY_GATE_BYPASS=intentional override", "header": "h", "options": [{"label": "a", "description": "a"}, {"label": "b", "description": "b"}]}]}
}
JSON
)

echo "${INPUT_JSON}" | bash "${GATE}" >/dev/null 2>/dev/null
ACTUAL=$?
assert_exit "Bypass token → allow" "0" "${ACTUAL}"

# ===== Summary =====
echo ""
echo "─────────────────────────────────────────"
echo "PASS: ${PASS}    FAIL: ${FAIL}"
echo "─────────────────────────────────────────"

# cleanup
rm -rf "${PROJECT_DIR}"

[ "${FAIL}" -eq 0 ] && exit 0 || exit 1
