#!/usr/bin/env bash
# worktree-only-gate.sh — GLUEBOY worktree-only source edit gate
# ---------------------------------------------------------------------------
# PreToolUse hook for Edit|Write|MultiEdit. Blocks source-code edits when the current
# session is running in a main repo checkout instead of a git worktree.
#
# Allowed in main sessions:
#   - oracle-build/*
#   - CLAUDE.md
#   - AGENTS.md
#   - ψ/*
#   - .claude config/markdown files
#   - comment-only changes
#   - single-line typo fixes in comments/strings
#
# Override: include GLUEBOY_GATE_BYPASS=<reason> in the tool input. Bypasses
# are logged to ~/.claude/.worktree-only-gate/gate.log.
#
# Fail-open: internal gate errors exit 0 and stay quiet. This hook must never
# break a tool call because the gate itself failed.
# ---------------------------------------------------------------------------
set -u

GATE_DIR="${HOME}/.claude/.worktree-only-gate"
LOG="${GATE_DIR}/gate.log"
mkdir -p "${GATE_DIR}" 2>/dev/null || true

INPUT="$(cat 2>/dev/null || true)"
[ -z "${INPUT}" ] && exit 0

log() {
  printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "${LOG}" 2>/dev/null || true
}

fail_open() {
  log "FAIL-OPEN $*"
  exit 0
}

make_temp() {
  mktemp "${TMPDIR:-/tmp}/worktree-only-gate.XXXXXX" 2>/dev/null || return 1
}

INPUT_FILE="$(make_temp || true)"
[ -z "${INPUT_FILE}" ] && fail_open "no-input-tempfile"
printf '%s' "${INPUT}" > "${INPUT_FILE}" 2>/dev/null || fail_open "write-input-tempfile"
cleanup_files="${INPUT_FILE}"
cleanup() {
  for f in ${cleanup_files}; do
    [ -n "${f}" ] && [ -f "${f}" ] && rm -f "${f}" 2>/dev/null || true
  done
}
trap cleanup EXIT

json_top_field() {
  local field="$1"
  python3 - "${INPUT_FILE}" "${field}" <<'PY' 2>/dev/null || true
import json
import sys

path, field = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        obj = json.load(f)
    value = obj.get(field, "")
    if isinstance(value, (str, int, float, bool)):
        print(value)
except Exception:
    pass
PY
}

json_tool_field() {
  local field="$1"
  python3 - "${INPUT_FILE}" "${field}" <<'PY' 2>/dev/null || true
import json
import sys

path, field = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        obj = json.load(f)
    value = obj.get("tool_input", {}).get(field, "")
    if isinstance(value, (str, int, float, bool)):
        print(value)
    elif value is not None:
        print(json.dumps(value, ensure_ascii=False))
except Exception:
    pass
PY
}

BYPASS_REASON="$(python3 - "${INPUT_FILE}" <<'PY' 2>/dev/null || true
import json
import re
import sys

def walk(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)

try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        obj = json.load(f)
    haystack = "\n".join(walk(obj))
except Exception:
    haystack = ""

match = re.search(r"GLUEBOY_GATE_BYPASS=([^\"'\s]+)", haystack)
if match:
    print(match.group(1))
PY
)"
if [ -n "${BYPASS_REASON}" ]; then
  log "BYPASS reason=${BYPASS_REASON}"
  exit 0
fi

EVENT="$(json_top_field hook_event_name)"
[ "${EVENT}" = "PreToolUse" ] || exit 0

TOOL_NAME="$(json_top_field tool_name)"
case "${TOOL_NAME}" in
  Edit|Write|MultiEdit) ;;
  "") fail_open "no-tool-name" ;;
  *) exit 0 ;;
esac

TARGET_FILE="$(json_tool_field file_path)"
[ -n "${TARGET_FILE}" ] || fail_open "no-file-path tool=${TOOL_NAME}"

ABS_TARGET="$(python3 - "${PWD}" "${TARGET_FILE}" <<'PY' 2>/dev/null || true
import os
import sys

cwd, path = sys.argv[1], sys.argv[2]
if not os.path.isabs(path):
    path = os.path.join(cwd, path)
print(os.path.normpath(path))
PY
)"
[ -n "${ABS_TARGET}" ] || fail_open "normalize-target"

TARGET_GIT_CWD="$(python3 - "${ABS_TARGET}" <<'PY' 2>/dev/null || true
import os
import sys

path = os.path.normpath(sys.argv[1])
candidate = path if os.path.isdir(path) else os.path.dirname(path)
while candidate and not os.path.exists(candidate):
    parent = os.path.dirname(candidate)
    if parent == candidate:
        break
    candidate = parent
if candidate and os.path.isdir(candidate):
    print(candidate)
PY
)"
[ -n "${TARGET_GIT_CWD}" ] || exit 0

REPO_ROOT="$(git -C "${TARGET_GIT_CWD}" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "${REPO_ROOT}" ] || exit 0

GIT_COMMON_DIR="$(git -C "${TARGET_GIT_CWD}" rev-parse --git-common-dir 2>/dev/null || true)"
GIT_DIR="$(git -C "${TARGET_GIT_CWD}" rev-parse --git-dir 2>/dev/null || true)"
[ -n "${GIT_COMMON_DIR}" ] || fail_open "no-git-common-dir"
[ -n "${GIT_DIR}" ] || fail_open "no-git-dir"

ABS_GIT_COMMON_DIR="$(python3 - "${TARGET_GIT_CWD}" "${GIT_COMMON_DIR}" <<'PY' 2>/dev/null || true
import os
import sys

cwd, path = sys.argv[1], sys.argv[2]
if not os.path.isabs(path):
    path = os.path.join(cwd, path)
print(os.path.realpath(path))
PY
)"
ABS_GIT_DIR="$(python3 - "${TARGET_GIT_CWD}" "${GIT_DIR}" <<'PY' 2>/dev/null || true
import os
import sys

cwd, path = sys.argv[1], sys.argv[2]
if not os.path.isabs(path):
    path = os.path.join(cwd, path)
print(os.path.realpath(path))
PY
)"
[ -n "${ABS_GIT_COMMON_DIR}" ] || fail_open "normalize-common-dir"
[ -n "${ABS_GIT_DIR}" ] || fail_open "normalize-git-dir"

REL_PATH="$(python3 - "${REPO_ROOT}" "${ABS_TARGET}" <<'PY' 2>/dev/null || true
import os
import sys

root, target = map(os.path.realpath, sys.argv[1:3])
try:
    if os.path.commonpath([root, target]) != root:
        sys.exit(0)
    print(os.path.relpath(target, root))
except Exception:
    sys.exit(0)
PY
)"
[ -n "${REL_PATH}" ] || exit 0

# A git worktree has a per-worktree git-dir under the common dir. Main checkout
# has git-dir == git-common-dir. Check the target path's repo, not just cwd.
if [ "${ABS_GIT_COMMON_DIR}" != "${ABS_GIT_DIR}" ]; then
  log "PASS worktree tool=${TOOL_NAME} path=${REL_PATH}"
  exit 0
fi

is_allowed_main_path() {
  local rel="$1"
  case "${rel}" in
    oracle-build/*|CLAUDE.md|AGENTS.md|ψ/*)
      return 0
      ;;
    .claude/*.json|.claude/*.md|.claude/settings.local.json|.claude/agents/*.md|.claude/plans/*.md)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_source_path() {
  local rel="$1"
  case "${rel}" in
    *.md|*.json|*.toml|*.yaml|*.yml|*.gitignore|*.gitattributes)
      return 1
      ;;
    oracle-build/*.sh|oracle-build/*.bash|oracle-build/*.zsh)
      return 1
      ;;
  esac

  case "${rel}" in
    scripts/*|src/*|lib/*|app/*|pkg/*|cmd/*|internal/*|test/*|tests/*|spec/*|specs/*|e2e/*)
      return 0
      ;;
  esac

  case "${rel}" in
    *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.sh|*.bash|*.zsh|*.rb|*.java|*.kt|*.swift)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

write_field_to_temp() {
  local field="$1"
  local out_file="$2"
  python3 - "${INPUT_FILE}" "${field}" "${out_file}" <<'PY' 2>/dev/null || true
import json
import sys

input_path, field, out_path = sys.argv[1:4]
try:
    with open(input_path, "r", encoding="utf-8") as f:
        obj = json.load(f)
    value = obj.get("tool_input", {}).get(field, "")
    if not isinstance(value, str):
        value = "" if value is None else str(value)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(value)
except Exception:
    pass
PY
}

write_multiedit_to_temps() {
  local old_file="$1"
  local new_file="$2"
  python3 - "${INPUT_FILE}" "${old_file}" "${new_file}" <<'PY' 2>/dev/null
import json
import sys

input_path, old_path, new_path = sys.argv[1:4]
try:
    with open(input_path, "r", encoding="utf-8") as f:
        obj = json.load(f)
    edits = obj.get("tool_input", {}).get("edits", [])
    if not isinstance(edits, list) or not edits:
        sys.exit(1)
    old_parts = []
    new_parts = []
    for edit in edits:
        if not isinstance(edit, dict):
            sys.exit(1)
        old = edit.get("old_string", "")
        new = edit.get("new_string", "")
        if not isinstance(old, str) or not isinstance(new, str):
            sys.exit(1)
        old_parts.append(old)
        new_parts.append(new)
    with open(old_path, "w", encoding="utf-8") as f:
        f.write("\n".join(old_parts))
    with open(new_path, "w", encoding="utf-8") as f:
        f.write("\n".join(new_parts))
except Exception:
    sys.exit(1)
PY
}

change_is_main_session_exception() {
  local old_file="$1"
  local new_file="$2"
  python3 - "${old_file}" "${new_file}" <<'PY' 2>/dev/null
import difflib
import re
import sys

old_path, new_path = sys.argv[1:3]
try:
    with open(old_path, "r", encoding="utf-8", errors="ignore") as f:
        old = f.read()
    with open(new_path, "r", encoding="utf-8", errors="ignore") as f:
        new = f.read()
except Exception:
    sys.exit(1)

def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    out = []
    for line in text.splitlines():
        quote = ""
        escaped = False
        cut = len(line)
        i = 0
        while i < len(line):
            ch = line[i]
            nxt = line[i + 1] if i + 1 < len(line) else ""
            if quote:
                if escaped:
                    escaped = False
                elif ch == "\\":
                    escaped = True
                elif ch == quote:
                    quote = ""
                i += 1
                continue
            if ch in ("'", '"', "`"):
                quote = ch
                i += 1
                continue
            if ch == "#":
                cut = i
                break
            if ch == "/" and nxt == "/":
                cut = i
                break
            i += 1
        out.append(line[:cut].rstrip())
    return "\n".join(out).strip()

def strip_strings(text):
    no_comments = strip_comments(text)
    string_re = re.compile(
        r'"(?:\\.|[^"\\])*"'
        r"|'(?:\\.|[^'\\])*'"
        r"|`(?:\\.|[^`\\])*`",
        flags=re.S,
    )
    return string_re.sub('""', no_comments).strip()

def string_literals(text):
    no_comments = strip_comments(text)
    string_re = re.compile(
        r'"(?:\\.|[^"\\])*"'
        r"|'(?:\\.|[^'\\])*'"
        r"|`(?:\\.|[^`\\])*`",
        flags=re.S,
    )
    out = []
    for match in string_re.finditer(no_comments):
        literal = match.group(0)
        if len(literal) >= 2:
            out.append(literal[1:-1])
    return out

def levenshtein(a, b):
    if a == b:
        return 0
    if abs(len(a) - len(b)) > 2:
        return 3
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(
                prev[j] + 1,
                cur[j - 1] + 1,
                prev[j - 1] + (0 if ca == cb else 1),
            ))
        prev = cur
    return prev[-1]

if strip_comments(old) == strip_comments(new):
    sys.exit(0)

diff = difflib.ndiff(old.splitlines(), new.splitlines())
changed_lines = sum(1 for line in diff if line.startswith("- ") or line.startswith("+ "))
if changed_lines < 3 and strip_strings(old) == strip_strings(new):
    old_literals = string_literals(old)
    new_literals = string_literals(new)
    changed_pairs = [
        (a, b)
        for a, b in zip(old_literals, new_literals)
        if a != b
    ]
    if (
        len(old_literals) == len(new_literals)
        and len(changed_pairs) == 1
        and levenshtein(changed_pairs[0][0], changed_pairs[0][1]) <= 2
    ):
        sys.exit(0)

sys.exit(1)
PY
}

if is_allowed_main_path "${REL_PATH}"; then
  log "PASS allowed-path tool=${TOOL_NAME} path=${REL_PATH}"
  exit 0
fi

if ! is_source_path "${REL_PATH}"; then
  log "PASS non-source tool=${TOOL_NAME} path=${REL_PATH}"
  exit 0
fi

OLD_TMP="$(make_temp || true)"
NEW_TMP="$(make_temp || true)"
[ -n "${OLD_TMP}" ] || fail_open "no-old-tempfile"
[ -n "${NEW_TMP}" ] || fail_open "no-new-tempfile"
cleanup_files="${cleanup_files} ${OLD_TMP} ${NEW_TMP}"

case "${TOOL_NAME}" in
  Edit)
    write_field_to_temp old_string "${OLD_TMP}"
    write_field_to_temp new_string "${NEW_TMP}"
    ;;
  Write)
    if [ -f "${ABS_TARGET}" ] && [ -r "${ABS_TARGET}" ]; then
      cp "${ABS_TARGET}" "${OLD_TMP}" 2>/dev/null || : > "${OLD_TMP}"
    else
      : > "${OLD_TMP}"
    fi
    write_field_to_temp content "${NEW_TMP}"
    ;;
  MultiEdit)
    if ! write_multiedit_to_temps "${OLD_TMP}" "${NEW_TMP}"; then
      fail_open "multi-edit-parse"
    fi
    ;;
esac

if change_is_main_session_exception "${OLD_TMP}" "${NEW_TMP}"; then
  log "PASS comment-or-string-only tool=${TOOL_NAME} path=${REL_PATH}"
  exit 0
fi

log "BLOCK main-session-source-edit tool=${TOOL_NAME} path=${REL_PATH}"
cat >&2 <<EOF
WORKTREE-ONLY GATE BLOCKED

Source-code edits must happen in a maw worktree, not the main repo checkout.

Path: ${REL_PATH}
Tool: ${TOOL_NAME}

Allowed main-session exceptions:
  - oracle-build/*
  - CLAUDE.md
  - AGENTS.md
  - ψ/*
  - .claude config/markdown files
  - comment-only changes
  - single-line typo fixes in comments/strings

Use a worktree for this edit, or include GLUEBOY_GATE_BYPASS=<reason> in the
tool input for an intentional logged override.
EOF
exit 2
