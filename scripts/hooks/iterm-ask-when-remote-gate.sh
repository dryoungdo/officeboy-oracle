#!/usr/bin/env bash
# iterm-ask-when-remote-gate.sh — GLUEBOY iTerm-Ask-When-Remote Gate
# ---------------------------------------------------------------------------
# PreToolUse hook on AskUserQuestion. Blocks the call when Captain's most
# recent user input came from a Discord channel.
#
# Why: AskUserQuestion is an iTerm-bound TUI primitive — it renders only in
# the active Claude Code pane. Captain on Discord cannot see or answer it,
# and GLUEBOY blocks waiting indefinitely. On 2026-05-24 this caused a 6h+
# silent stall after Codex review hung (rrr retro: 09.32_l3-wind-pattern-
# adopted-codex-hang-cleanup.md, session-metrics Instance 9b).
#
# Replacement: when Captain is remote, send a `mcp__plugin_discord_discord__
# reply` with numbered options and wait for the channel inbound response.
#
# Detection rule: scan the session JSONL for the MOST RECENT user message;
# if it contains `<channel source="plugin:discord:discord"` → block. If the
# most recent user input was at iTerm (no Discord channel marker), allow.
#
# Fail-open if JSONL not found / session_id missing — never break the call
# on internal error; just log it.
# ---------------------------------------------------------------------------
set -u

GATE_DIR="${HOME}/.claude/.iterm-ask-gate"
LOG="${GATE_DIR}/gate.log"
mkdir -p "${GATE_DIR}" 2>/dev/null || true

INPUT="$(cat 2>/dev/null || true)"
[ -z "${INPUT}" ] && exit 0

log() { printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "${LOG}" 2>/dev/null || true; }

# --- which hook event (allow whitespace around colon) ---
EVENT="$(printf '%s' "${INPUT}" | grep -oE '"hook_event_name"[[:space:]]*:[[:space:]]*"[A-Za-z]+"' | head -1 | grep -oE '"[A-Za-z]+"$' | tr -d '"')"
[ "${EVENT}" != "PreToolUse" ] && exit 0

# --- which tool — only gate AskUserQuestion ---
TOOL="$(printf '%s' "${INPUT}" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[A-Za-z_]+"' | head -1 | grep -oE '"[A-Za-z_]+"$' | tr -d '"')"
[ "${TOOL}" != "AskUserQuestion" ] && exit 0

# --- session id (UUID) ---
SESSION="$(printf '%s' "${INPUT}" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[A-Za-z0-9-]+"' | head -1 | grep -oE '"[A-Za-z0-9-]+"$' | tr -d '"')"
if [ -z "${SESSION}" ]; then
  log "FAIL-OPEN no-session-id"
  exit 0
fi

# --- find session JSONL ---
JSONL="$(find "${HOME}/.claude/projects" -maxdepth 3 -name "${SESSION}.jsonl" -type f 2>/dev/null | head -1)"
if [ -z "${JSONL}" ] || [ ! -r "${JSONL}" ]; then
  log "FAIL-OPEN no-jsonl session=${SESSION}"
  exit 0
fi

# --- most recent USER message (not assistant, not attachment) ---
# Strategy: scan from end of file backward, find first real user-typed message
# (skip tool_results, attachments, system reminders). A user "input" message
# has type=user AND its content is either a plain string or a list with
# top-level text (not tool_result entries).
LAST_USER_LINE="$(python3 - "${JSONL}" <<'PY' 2>/dev/null
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        lines = f.readlines()
except Exception:
    sys.exit(0)
# scan from end backward
for line in reversed(lines):
    try:
        m = json.loads(line)
    except Exception:
        continue
    if m.get("type") != "user":
        continue
    msg = m.get("message", {})
    content = msg.get("content", "")
    # Plain-string content = a real user input
    if isinstance(content, str):
        print(content)
        sys.exit(0)
    # List content: only count if it has direct text (not just tool_result)
    if isinstance(content, list):
        text_parts = []
        only_tool_result = True
        for c in content:
            if isinstance(c, dict):
                t = c.get("type", "")
                if t == "text":
                    text_parts.append(c.get("text", ""))
                    only_tool_result = False
                elif t != "tool_result":
                    only_tool_result = False
        if not only_tool_result and text_parts:
            print("\n".join(text_parts))
            sys.exit(0)
PY
)"

if [ -z "${LAST_USER_LINE}" ]; then
  log "FAIL-OPEN no-user-message session=${SESSION}"
  exit 0
fi

# --- explicit one-shot bypass ---
QUESTIONS_TEXT="$(printf '%s' "${INPUT}" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    qs=d.get("tool_input",{}).get("questions",[])
    print(" | ".join(q.get("question","") for q in qs))
except Exception:
    pass' 2>/dev/null)"

case "${QUESTIONS_TEXT}" in
  *GLUEBOY_GATE_BYPASS*)
    log "BYPASS session=${SESSION} questions=${QUESTIONS_TEXT}"
    exit 0
    ;;
esac

# --- the rule: Discord channel marker in most recent user input → block ---
case "${LAST_USER_LINE}" in
  *'<channel source="plugin:discord:discord"'*)
    # Extract chat_id if present, for the helpful hint
    CHAT_ID="$(printf '%s' "${LAST_USER_LINE}" | grep -oE 'chat_id="[0-9]+"' | head -1 | grep -oE '[0-9]+')"
    [ -z "${CHAT_ID}" ] && CHAT_ID="<see channel tag>"
    log "BLOCK session=${SESSION} chat_id=${CHAT_ID} questions=${QUESTIONS_TEXT}"
    cat >&2 <<EOF
🎙️ ITERM-ASK GATE — Captain is on Discord (chat_id=${CHAT_ID}).

AskUserQuestion renders only in the active Claude Code pane — Captain on Discord cannot see or answer it. If you proceed, GLUEBOY will block waiting indefinitely (this is the bug from 2026-05-24, session-metrics Instance 9b — 6h+ silent stall after Codex hang).

Use this instead:

  mcp__plugin_discord_discord__reply({
    chat_id: "${CHAT_ID}",
    text: "<your question>\\n\\n1. <option-1>\\n2. <option-2>\\n3. <option-3>\\n\\nตอบเลขเดียวพอ."
  })

Captain replies with a number on Discord; you receive it as an inbound <channel> message.

(Override: include 'GLUEBOY_GATE_BYPASS' anywhere in your question text — logged.)
EOF
    exit 2
    ;;
  *)
    log "PASS session=${SESSION} (iTerm input)"
    exit 0
    ;;
esac
