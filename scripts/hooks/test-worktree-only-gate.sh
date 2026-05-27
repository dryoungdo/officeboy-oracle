#!/usr/bin/env bash
# test-worktree-only-gate.sh — verify the GLUEBOY worktree-only gate
# ---------------------------------------------------------------------------
# Covers pass-through behavior, main checkout blocking, worktree allowing,
# allowed-list paths, bypass logging, and comment/string-only edit exceptions.
#
# Run: bash scripts/hooks/test-worktree-only-gate.sh
# ---------------------------------------------------------------------------
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="${REPO_ROOT}/scripts/hooks/worktree-only-gate.sh"

PASS=0
FAIL=0
FAILED_CASES=""

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/worktree-only-gate-test.XXXXXX" 2>/dev/null || true)"
if [ -z "${TEST_ROOT}" ]; then
  printf 'FAIL: could not create temp test root\n' >&2
  exit 1
fi

MAIN_REPO="${TEST_ROOT}/main"
WORKTREE_REPO="${TEST_ROOT}/worktree"

mkdir -p "${MAIN_REPO}" 2>/dev/null || { printf 'FAIL: could not create main repo\n' >&2; exit 1; }

(
  cd "${MAIN_REPO}" || exit 1
  git init -q
  git config user.email "test@example.com"
  git config user.name "Worktree Gate Test"
  mkdir -p scripts oracle-build ψ/memory/learnings .claude/scripts
  printf '#!/usr/bin/env bash\nprintf "hello\\n"\n' > scripts/foo.sh
  printf '# shared doctrine\n' > oracle-build/shared-claude.md
  printf '# learning\n' > ψ/memory/learnings/x.md
  printf '# claude\n' > CLAUDE.md
  printf '# agents\n' > AGENTS.md
  printf '{}\n' > .claude/settings.local.json
  git add scripts/foo.sh oracle-build/shared-claude.md ψ/memory/learnings/x.md CLAUDE.md AGENTS.md .claude/settings.local.json
  git commit -q -m "initial"
  git worktree add -q "${WORKTREE_REPO}" HEAD
)
SETUP_RC=$?
if [ "${SETUP_RC}" -ne 0 ]; then
  printf 'FAIL: could not set up synthetic git repo/worktree\n' >&2
  exit 1
fi

json_escape() {
  python3 - "$1" <<'PY'
import json
import sys

print(json.dumps(sys.argv[1], ensure_ascii=False))
PY
}

edit_input() {
  local file_path="$1"
  local old_string="$2"
  local new_string="$3"
  printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":%s,"old_string":%s,"new_string":%s},"session_id":"test"}' \
    "$(json_escape "${file_path}")" \
    "$(json_escape "${old_string}")" \
    "$(json_escape "${new_string}")"
}

write_input() {
  local file_path="$1"
  local content="$2"
  printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":%s,"content":%s},"session_id":"test"}' \
    "$(json_escape "${file_path}")" \
    "$(json_escape "${content}")"
}

multiedit_input() {
  local file_path="$1"
  local old_string="$2"
  local new_string="$3"
  python3 - "${file_path}" "${old_string}" "${new_string}" <<'PY'
import json
import sys

file_path, old_string, new_string = sys.argv[1:4]
print(json.dumps({
    "hook_event_name": "PreToolUse",
    "tool_name": "MultiEdit",
    "tool_input": {
        "file_path": file_path,
        "edits": [{"old_string": old_string, "new_string": new_string}],
    },
    "session_id": "test",
}, ensure_ascii=False))
PY
}

run_case() {
  local name="$1"
  local cwd="$2"
  local expected="$3"
  local input="$4"

  (
    cd "${cwd}" || exit 99
    printf '%s' "${input}" | bash "${HOOK}" >/tmp/worktree-only-gate-test.out 2>/tmp/worktree-only-gate-test.err
  )
  local actual=$?

  if [ "${actual}" = "${expected}" ]; then
    printf '  PASS %s (exit %s)\n' "${name}" "${actual}"
    PASS=$((PASS + 1))
  else
    printf '  FAIL %s — expected exit %s, got %s\n' "${name}" "${expected}" "${actual}"
    FAIL=$((FAIL + 1))
    FAILED_CASES="${FAILED_CASES}\n  - ${name}"
  fi
}

printf '\n[group] Gate basics\n'

run_case "ALLOW: empty input" "${MAIN_REPO}" 0 ""

run_case "ALLOW: malformed JSON fails open" "${MAIN_REPO}" 0 \
  '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":'

run_case "ALLOW: PostToolUse pass-through" "${MAIN_REPO}" 0 \
  '{"hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"scripts/foo.sh"}}'

run_case "ALLOW: Bash pass-through" "${MAIN_REPO}" 0 \
  '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"echo hi"}}'

run_case "ALLOW: missing file_path fails open" "${MAIN_REPO}" 0 \
  '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"old_string":"x","new_string":"y"}}'

run_case "ALLOW: outside git repo" "${TEST_ROOT}" 0 \
  "$(edit_input "${TEST_ROOT}/outside.py" 'x = 1' 'x = 2')"

printf '\n[group] Main checkout vs worktree\n'

run_case "BLOCK: Edit scripts/foo.sh in MAIN checkout"  "${MAIN_REPO}" 2 \
  "$(edit_input "${MAIN_REPO}/scripts/foo.sh" 'printf "hello\n"' 'echo "hello\n"')"

run_case "ALLOW: Edit scripts/foo.sh in WORKTREE checkout" "${WORKTREE_REPO}" 0 \
  "$(edit_input "${WORKTREE_REPO}/scripts/foo.sh" 'printf "hello\n"' 'echo "hello\n"')"

run_case "BLOCK: MultiEdit scripts/foo.sh in MAIN checkout" "${MAIN_REPO}" 2 \
  "$(multiedit_input "${MAIN_REPO}/scripts/foo.sh" 'printf "hello\n"' 'echo "hello\n"')"

run_case "ALLOW: MultiEdit scripts/foo.sh in WORKTREE checkout" "${WORKTREE_REPO}" 0 \
  "$(multiedit_input "${WORKTREE_REPO}/scripts/foo.sh" 'printf "hello\n"' 'echo "hello\n"')"

run_case "BLOCK: worktree cwd targeting MAIN checkout absolute path" "${WORKTREE_REPO}" 2 \
  "$(edit_input "${MAIN_REPO}/scripts/foo.sh" 'printf "hello\n"' 'echo "hello\n"')"

printf '\n[group] Main-session allowed-list exceptions\n'

run_case "ALLOW: oracle-build/shared-claude.md" "${MAIN_REPO}" 0 \
  "$(edit_input "${MAIN_REPO}/oracle-build/shared-claude.md" '# shared doctrine' '# shared doctrine updated')"

run_case "ALLOW: ψ/memory/learnings/x.md" "${MAIN_REPO}" 0 \
  "$(edit_input "${MAIN_REPO}/ψ/memory/learnings/x.md" '# learning' '# learning updated')"

run_case "ALLOW: CLAUDE.md" "${MAIN_REPO}" 0 \
  "$(edit_input "${MAIN_REPO}/CLAUDE.md" '# claude' '# claude updated')"

run_case "ALLOW: AGENTS.md" "${MAIN_REPO}" 0 \
  "$(edit_input "${MAIN_REPO}/AGENTS.md" '# agents' '# agents updated')"

run_case "ALLOW: .claude/settings.local.json" "${MAIN_REPO}" 0 \
  "$(edit_input "${MAIN_REPO}/.claude/settings.local.json" '{}' '{"permissions":{"allow":[]}}')"

run_case "BLOCK: .claude/scripts/foo.sh source code" "${MAIN_REPO}" 2 \
  "$(write_input "${MAIN_REPO}/.claude/scripts/foo.sh" "$(printf '#!/usr/bin/env bash\nprintf "config code\\n"\n')")"

run_case "ALLOW: oracle-build/foo.sh" "${MAIN_REPO}" 0 \
  "$(write_input "${MAIN_REPO}/oracle-build/foo.sh" "$(printf '#!/usr/bin/env bash\nprintf "doctrine helper\\n"\n')")"

printf '\n[group] Source classification\n'

run_case "BLOCK: src/foo.ts in MAIN checkout" "${MAIN_REPO}" 2 \
  "$(write_input "${MAIN_REPO}/src/foo.ts" "$(printf 'export const value = 1;\n')")"

run_case "BLOCK: root foo.py by extension in MAIN checkout" "${MAIN_REPO}" 2 \
  "$(write_input "${MAIN_REPO}/foo.py" "$(printf 'print("hello")\n')")"

run_case "ALLOW: README.md non-source" "${MAIN_REPO}" 0 \
  "$(write_input "${MAIN_REPO}/README.md" "$(printf '# README\n')")"

run_case "ALLOW: package.json non-source" "${MAIN_REPO}" 0 \
  "$(write_input "${MAIN_REPO}/package.json" '{"name":"fixture"}')"

run_case "ALLOW: config.yaml non-source" "${MAIN_REPO}" 0 \
  "$(write_input "${MAIN_REPO}/config.yaml" "$(printf 'name: fixture\n')")"

printf '\n[group] Main-session narrow edit exceptions\n'

run_case "ALLOW: comment-only source edit in MAIN checkout" "${MAIN_REPO}" 0 \
  "$(edit_input "${MAIN_REPO}/scripts/foo.sh" '# old comment' '# new comment')"

run_case "ALLOW: single-line string typo in MAIN checkout" "${MAIN_REPO}" 0 \
  "$(edit_input "${MAIN_REPO}/scripts/foo.sh" 'printf "helo\n"' 'printf "hello\n"')"

run_case "BLOCK: semantic string edit in MAIN checkout" "${MAIN_REPO}" 2 \
  "$(edit_input "${MAIN_REPO}/scripts/foo.sh" 'endpoint="/users"' 'endpoint="/admin/delete"')"

run_case "BLOCK: single-line actual code change in MAIN checkout" "${MAIN_REPO}" 2 \
  "$(edit_input "${MAIN_REPO}/scripts/foo.sh" 'printf "hello\n"' 'echo "hello\n"')"

run_case "BLOCK: Write new source code in MAIN checkout" "${MAIN_REPO}" 2 \
  "$(write_input "${MAIN_REPO}/scripts/new-tool.sh" "$(printf '#!/usr/bin/env bash\nprintf "new\\n"\n')")"

printf '\n[group] Bypass override\n'

run_case "ALLOW: GLUEBOY_GATE_BYPASS override" "${MAIN_REPO}" 0 \
  '{"hook_event_name":"PreToolUse","tool_name":"Edit","tool_input":{"file_path":"scripts/foo.sh","old_string":"x","new_string":"y","note":"GLUEBOY_GATE_BYPASS=test-override"},"session_id":"test"}'

printf '\n=== test-worktree-only-gate.sh summary ===\n'
TOTAL=$((PASS + FAIL))
printf '  Total: %d   PASS: %d   FAIL: %d\n' "${TOTAL}" "${PASS}" "${FAIL}"
printf '  Test root left for inspection: %s\n' "${TEST_ROOT}"

if [ "${FAIL}" -gt 0 ]; then
  printf '\nFailed cases:%b\n' "${FAILED_CASES}"
  exit 1
fi

printf '\nAll tests passed.\n'
exit 0
