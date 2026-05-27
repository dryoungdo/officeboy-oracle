# sop-qa-rules/03-bypass-flag.sh — Rule 3: codex tile bypass flag
# ---------------------------------------------------------------------------
# When spawning a codex tile with `maw tile`, the command MUST include
# `--dangerously-bypass-approvals-and-sandbox` — otherwise codex starts with
# the default readonly profile and can draft a patch in TUI scrollback without
# writing files.
#
# Surfaced as issue #46 on 2026-05-24 during orchestrator+codex tile dispatch.
#
# Applies: PreToolUse Bash with command invoking "maw tile" and word "codex"
# Check: pass only when the bypass flag is present
# ---------------------------------------------------------------------------

sop_qa_rule_bypass_flag_invokes_maw_tile() {
  SOP_QA_BYPASS_FLAG_COMMAND="$1" python3 - <<'PY' 2>/dev/null
import os
import shlex
import sys

COMMAND = os.environ.get("SOP_QA_BYPASS_FLAG_COMMAND", "")
PUNCTUATION = set(";&|()\n")
BOUNDARY_WORDS = {"then", "do", "else", "elif"}
CONTROL_PREFIXES = {"if", "until", "while"}
SHELLS = {"bash", "dash", "ksh", "sh", "zsh"}
COMMAND_PREFIXES = {"command", "env", "exec", "sudo", "time"}


def tokenize(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = "#"
    return list(lexer)


def is_boundary(token):
    return bool(token) and all(char in PUNCTUATION for char in token)


def is_shell(token):
    return os.path.basename(token) in SHELLS


def is_assignment(token):
    name, separator, _ = token.partition("=")
    if not separator or not name:
        return False
    return all(char == "_" or char.isalnum() for char in name)


def is_tile_clean(tokens, start):
    next_index = start + 2
    return next_index < len(tokens) and tokens[next_index] == "clean"


def shell_c_argument(tokens, start):
    index = start + 1
    while index < len(tokens) and not is_boundary(tokens[index]):
        token = tokens[index]
        if token == "-c" or (token.startswith("-") and "c" in token[1:]):
            next_index = index + 1
            if next_index < len(tokens) and not is_boundary(tokens[next_index]):
                return tokens[next_index]
            return None
        index += 1
    return None


def invokes_maw_tile(command, depth=0):
    if depth > 2:
        return False

    try:
        tokens = tokenize(command)
    except ValueError:
        return False

    may_start_command = True
    index = 0
    while index < len(tokens):
        token = tokens[index]

        if is_boundary(token):
            may_start_command = True
            index += 1
            continue

        if may_start_command and token in BOUNDARY_WORDS:
            may_start_command = True
            index += 1
            continue

        if may_start_command:
            if token == "maw" and index + 1 < len(tokens) and tokens[index + 1] == "tile":
                if is_tile_clean(tokens, index):
                    may_start_command = False
                    index += 1
                    continue
                return True

            if is_shell(token):
                nested = shell_c_argument(tokens, index)
                if nested and invokes_maw_tile(nested, depth + 1):
                    return True

            if token in CONTROL_PREFIXES or token in COMMAND_PREFIXES or is_assignment(token):
                index += 1
                continue

            if token.startswith("-"):
                index += 1
                continue

        may_start_command = False
        index += 1

    return False


sys.exit(0 if invokes_maw_tile(COMMAND) else 1)
PY
}

sop_qa_rule_bypass_flag_applies() {
  [ "${SOP_QA_TOOL}" = "Bash" ] || return 1

  local command
  command="$(sop_qa_tool_input_field command)"
  if [ -z "${command}" ]; then
    command="$(SOP_QA_BYPASS_FLAG_INPUT="${SOP_QA_INPUT:-}" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    obj = json.loads(os.environ.get("SOP_QA_BYPASS_FLAG_INPUT", ""))
    val = obj.get("tool_input", {}).get("command", "")
    if isinstance(val, str):
        print(val)
except Exception:
    pass
PY
)"
  fi
  [ -n "${command}" ] || return 1

  sop_qa_rule_bypass_flag_invokes_maw_tile "${command}" || return 1

  printf '%s' "${command}" | grep -qE '(^|[^[:alnum:]_])codex([^[:alnum:]_]|$)' || return 1
  return 0
}

sop_qa_rule_bypass_flag_check() {
  local command
  command="$(sop_qa_tool_input_field command)"
  if [ -z "${command}" ]; then
    command="$(SOP_QA_BYPASS_FLAG_INPUT="${SOP_QA_INPUT:-}" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    obj = json.loads(os.environ.get("SOP_QA_BYPASS_FLAG_INPUT", ""))
    val = obj.get("tool_input", {}).get("command", "")
    if isinstance(val, str):
        print(val)
except Exception:
    pass
PY
)"
  fi
  [ -n "${command}" ] || return 0  # fail-open

  case "${command}" in
    *"--dangerously-bypass-approvals-and-sandbox"*)
      return 0
      ;;
  esac

  sop_qa_emit_hint "bypass-flag" "Bash tool call starts a codex tile with \`maw tile\` but does not include \`--dangerously-bypass-approvals-and-sandbox\`.

   Per issue #46 bypass-flag doctrine:
   The default codex profile is readonly. Without the bypass flag, codex can
   produce a complete patch in TUI scrollback but never write files, commit, or
   push. This looks like progress until the dispatcher peeks and finds the work
   waiting for approval that never arrives.

   Use:
     maw tile 1 --path \"\$(pwd)\" --cmd \"codex --dangerously-bypass-approvals-and-sandbox\""
  return 1
}
