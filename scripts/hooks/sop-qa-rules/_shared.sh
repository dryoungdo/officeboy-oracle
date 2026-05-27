# sop-qa-rules/_shared.sh — Helpers sourced by every rule
# ---------------------------------------------------------------------------
# Provides:
#   - sop_qa_emit_hint <rule-name> <message>     → stderr block message
#   - sop_qa_recent_user_lines [N]               → last N user-text lines from session JSONL
#   - sop_qa_recent_assistant_lines [N]          → last N assistant-text lines
#   - sop_qa_recent_bash_commands [N]            → last N Bash tool commands from session JSONL
#   - sop_qa_tool_input_field <field>            → extract a top-level field from the tool_input JSON (best-effort)
#
# All helpers fail-soft (empty output on error) — never break the dispatcher.
# Designed for bash 3.2 compat (macOS default).
# ---------------------------------------------------------------------------

# Emit a structured block hint to stderr. Each rule that BLOCKs calls this.
sop_qa_emit_hint() {
  local rule="$1"
  shift
  printf '\n🚦 SOP-QA GATE [%s] BLOCKED — %s\n' "${rule}" "$*" >&2
  printf '   (Override: include `GLUEBOY_GATE_BYPASS=<reason>` in your tool input — logged.)\n' >&2
}

# Read recent user-text content lines from the session JSONL (newest first).
# Returns nothing if JSONL not available. N defaults to 20.
sop_qa_recent_user_lines() {
  local n="${1:-20}"
  [ -z "${SOP_QA_JSONL:-}" ] && return 0
  [ ! -f "${SOP_QA_JSONL}" ] && return 0
  python3 - "${SOP_QA_JSONL}" "${n}" <<'PY' 2>/dev/null || true
import json, sys
jsonl = sys.argv[1]
n = int(sys.argv[2])
acc = []
try:
    with open(jsonl, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                m = json.loads(line)
                if m.get('type') != 'user': continue
                msg = m.get('message', {})
                content = msg.get('content', '')
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get('type') == 'text':
                            acc.append(c.get('text', ''))
                            break
                elif isinstance(content, str):
                    acc.append(content)
            except Exception:
                continue
except Exception:
    sys.exit(0)
for line in acc[-n:][::-1]:
    print(line.replace('\n', ' '))
PY
}

# Read recent assistant-text content lines (newest first).
sop_qa_recent_assistant_lines() {
  local n="${1:-20}"
  [ -z "${SOP_QA_JSONL:-}" ] && return 0
  [ ! -f "${SOP_QA_JSONL}" ] && return 0
  python3 - "${SOP_QA_JSONL}" "${n}" <<'PY' 2>/dev/null || true
import json, sys
jsonl = sys.argv[1]
n = int(sys.argv[2])
acc = []
try:
    with open(jsonl, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                m = json.loads(line)
                if m.get('type') != 'assistant': continue
                msg = m.get('message', {})
                content = msg.get('content', '')
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get('type') == 'text':
                            acc.append(c.get('text', ''))
                elif isinstance(content, str):
                    acc.append(content)
            except Exception:
                continue
except Exception:
    sys.exit(0)
for line in acc[-n:][::-1]:
    print(line.replace('\n', ' '))
PY
}

# Read recent Bash commands invoked in this session (newest first).
sop_qa_recent_bash_commands() {
  local n="${1:-20}"
  [ -z "${SOP_QA_JSONL:-}" ] && return 0
  [ ! -f "${SOP_QA_JSONL}" ] && return 0
  python3 - "${SOP_QA_JSONL}" "${n}" <<'PY' 2>/dev/null || true
import json, sys
jsonl = sys.argv[1]
n = int(sys.argv[2])
acc = []
try:
    with open(jsonl, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                m = json.loads(line)
                if m.get('type') != 'assistant': continue
                msg = m.get('message', {})
                content = msg.get('content', [])
                if not isinstance(content, list): continue
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'tool_use' and c.get('name') == 'Bash':
                        cmd = (c.get('input') or {}).get('command', '')
                        if cmd:
                            acc.append(cmd)
            except Exception:
                continue
except Exception:
    sys.exit(0)
for cmd in acc[-n:][::-1]:
    print(cmd.replace('\n', ' '))
PY
}

# Extract a top-level field from the tool_input JSON (best-effort regex).
# Usage: VALUE="$(sop_qa_tool_input_field command)"
sop_qa_tool_input_field() {
  local field="$1"
  printf '%s' "${SOP_QA_INPUT:-}" | python3 - "${field}" <<'PY' 2>/dev/null || true
import json, sys, re
field = sys.argv[1]
text = sys.stdin.read()
try:
    obj = json.loads(text)
    ti = obj.get('tool_input', {})
    val = ti.get(field, '')
    if isinstance(val, (str, int, float, bool)):
        print(val)
    else:
        print(json.dumps(val))
except Exception:
    sys.exit(0)
PY
}
