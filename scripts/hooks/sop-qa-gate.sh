#!/usr/bin/env bash
# sop-qa-gate.sh — GLUEBOY SOP-QA Top-5 Doctrine Compliance Gate
# ---------------------------------------------------------------------------
# PreToolUse hook that mechanically enforces the top-5 doctrine rules whose
# violations have surfaced repeatedly in session-metrics. Each rule is a
# separate file in scripts/hooks/sop-qa-rules/ and is sourced + dispatched
# from this main hook.
#
# The 5 rules (per #50 → #57 Captain decision 2026-05-24 18:00 ICT):
#   1. Swarm-by-Default — Edit/Write to source → require recent STRATEGY:
#   2. Issue-first — Edit/Write to tracked code repo → require GH issue ref
#   3. Bypass-flag — `maw tile` with codex but no bypass flag → block
#   4. Pane re-check — `maw hey <pane>` after kill without `maw panes` → block
#   5. bg-task wakeup — `run_in_background: true` Bash → require paired ScheduleWakeup
#
# Architecture: each rule sources `_shared.sh` for helpers and exports two
# functions: `sop_qa_rule_<slug>_applies` + `sop_qa_rule_<slug>_check`. The
# dispatcher calls applies() first (cheap match), then check() if applicable.
#
# Override: include `GLUEBOY_GATE_BYPASS=<reason>` in the tool input —
# the gate logs it (per-rule) and exits 0. Reason text is required.
#
# Fail-open: any internal error logs + exits 0. Never break a tool call due
# to gate bug.
# ---------------------------------------------------------------------------
set -u

GATE_DIR="${HOME}/.claude/.sop-qa-gate"
LOG="${GATE_DIR}/gate.log"
mkdir -p "${GATE_DIR}" 2>/dev/null || true

INPUT="$(cat 2>/dev/null || true)"
[ -z "${INPUT}" ] && exit 0

log() {
  printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "${LOG}" 2>/dev/null || true
}

# --- input parsing (shared with all rules via env) ---

# Hook event — only PreToolUse triggers this gate
EVENT="$(printf '%s' "${INPUT}" | grep -oE '"hook_event_name"[[:space:]]*:[[:space:]]*"[A-Za-z]+"' | head -1 | grep -oE '"[A-Za-z]+"$' | tr -d '"')"
[ "${EVENT}" != "PreToolUse" ] && exit 0

# Tool name — drives rule applicability
TOOL_NAME="$(printf '%s' "${INPUT}" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[A-Za-z_]+"' | head -1 | grep -oE '"[A-Za-z_]+"$' | tr -d '"')"
[ -z "${TOOL_NAME}" ] && { log "FAIL-OPEN no-tool-name"; exit 0; }

# Session id (UUID) — used to read recent assistant/user messages from JSONL
SESSION="$(printf '%s' "${INPUT}" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[A-Za-z0-9-]+"' | head -1 | grep -oE '"[A-Za-z0-9-]+"$' | tr -d '"')"

# Session JSONL — best-effort find. Rules that need conversation context use this.
JSONL=""
if [ -n "${SESSION}" ]; then
  JSONL="$(find "${HOME}/.claude/projects" -maxdepth 3 -name "${SESSION}.jsonl" -type f 2>/dev/null | head -1)"
fi

# --- bypass token (universal escape hatch) ---
if printf '%s' "${INPUT}" | grep -q 'GLUEBOY_GATE_BYPASS=[^"[:space:]]*[A-Za-z]'; then
  REASON="$(printf '%s' "${INPUT}" | grep -oE 'GLUEBOY_GATE_BYPASS=[^"[:space:]]+' | head -1)"
  log "BYPASS tool=${TOOL_NAME} reason=${REASON}"
  exit 0
fi

# --- export shared context to rules ---
export SOP_QA_TOOL="${TOOL_NAME}"
export SOP_QA_INPUT="${INPUT}"
export SOP_QA_SESSION="${SESSION}"
export SOP_QA_JSONL="${JSONL}"
export SOP_QA_LOG="${LOG}"

# --- locate rules dir + shared helpers ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_DIR="${SCRIPT_DIR}/sop-qa-rules"

if [ ! -d "${RULES_DIR}" ]; then
  log "FAIL-OPEN no-rules-dir at ${RULES_DIR}"
  exit 0
fi

if [ -f "${RULES_DIR}/_shared.sh" ]; then
  # shellcheck source=/dev/null
  . "${RULES_DIR}/_shared.sh"
fi

# --- iterate rules in lexical order (01- before 02-, etc.) ---
EXIT_CODE=0
for rule_file in "${RULES_DIR}"/[0-9][0-9]-*.sh; do
  [ -f "${rule_file}" ] || continue

  # shellcheck source=/dev/null
  . "${rule_file}"

  # Slug derives from filename: "01-swarm-by-default.sh" → "swarm_by_default"
  rule_slug="$(basename "${rule_file}" .sh | sed 's/^[0-9][0-9]-//; s/-/_/g')"

  applies_fn="sop_qa_rule_${rule_slug}_applies"
  check_fn="sop_qa_rule_${rule_slug}_check"

  if ! declare -F "${applies_fn}" >/dev/null 2>&1; then
    log "FAIL-OPEN rule=${rule_slug} no-applies-fn"
    continue
  fi
  if ! declare -F "${check_fn}" >/dev/null 2>&1; then
    log "FAIL-OPEN rule=${rule_slug} no-check-fn"
    continue
  fi

  if ! "${applies_fn}"; then
    continue  # rule doesn't apply to this tool/input
  fi

  if "${check_fn}"; then
    log "PASS rule=${rule_slug} tool=${TOOL_NAME}"
  else
    log "BLOCK rule=${rule_slug} tool=${TOOL_NAME}"
    EXIT_CODE=2
    # Don't break — let all applicable rules emit their hints in one shot
  fi
done

exit "${EXIT_CODE}"
