#!/usr/bin/env bash
# pre-claim-gate.sh — GLUEBOY Pre-Claim Gate
# ---------------------------------------------------------------------------
# Enforces a verify-before-act pause at the action boundary, to break the
# recurring "acted/shipped/broadcast on an unverified claim" error pattern
# (session-metrics.md, 6 instances). Design + rationale:
#   ψ/reference/pre-claim-gate.md
#
# Wired as a GLOBAL hook (universal coverage — most misses were cross-repo):
#   PreToolUse  → classify the action, gate it
#   PostToolUse → append one line to a per-session tool ledger (the evidence trail)
#
# Tiers:  ASK  → irreversible/public (pr merge, deploy, npm publish) → Captain approves
#         EVIDENCE → outward (push, pr/issue write, maw broadcast, TeamCreate)
#                    → blocked once; re-run only passes if a real tool call ran
#                      during the pause (prose is not evidence)
#         PASS → everything else, instant
#
# Non-negotiables: fail-LOUD for outward actions, fail-open for routine work;
# never commits/pushes/mutates repo state; only writes its own marker/ledger/log.
# ---------------------------------------------------------------------------
set -u

GATE_DIR="${HOME}/.claude/.pre-claim-gate"
LOG="${GATE_DIR}/gate.log"
mkdir -p "${GATE_DIR}" 2>/dev/null || true

INPUT="$(cat 2>/dev/null || true)"
[ -z "${INPUT}" ] && exit 0

log() { printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "${LOG}" 2>/dev/null || true; }

# --- which hook event (raw match, fast) ---
EVENT=""
case "${INPUT}" in
  *'"hook_event_name":"PreToolUse"'*)  EVENT="PreToolUse" ;;
  *'"hook_event_name":"PostToolUse"'*) EVENT="PostToolUse" ;;
esac
[ -z "${EVENT}" ] && exit 0

# --- session id (UUID — grep-safe) ---
SESSION="$(printf '%s' "${INPUT}" | grep -oE '"session_id":[[:space:]]*"[A-Za-z0-9-]+"' | head -1 | grep -oE '[A-Za-z0-9-]+"$' | tr -d '"')"
[ -z "${SESSION}" ] && SESSION="nosession"
LEDGER="${GATE_DIR}/ledger-${SESSION}"

ledger_lines() { local n; n="$(wc -l < "${LEDGER}" 2>/dev/null | tr -d ' \n')"; echo "${n:-0}"; }

# ===== PostToolUse: record that a tool ran, then exit =====
if [ "${EVENT}" = "PostToolUse" ]; then
  printf 'x\n' >> "${LEDGER}" 2>/dev/null || true
  exit 0
fi

# ===== PreToolUse =====
TOOL="$(printf '%s' "${INPUT}" | grep -oE '"tool_name":[[:space:]]*"[A-Za-z_]+"' | head -1 | grep -oE '[A-Za-z_]+"$' | tr -d '"')"

# fast-path: only a Bash command with a risky keyword, or a TeamCreate, is inspected
case "${TOOL}" in
  TeamCreate) ;;
  Bash)
    case "${INPUT}" in
      *push*|*merge*|*deploy*|*publish*|*'maw '*|*'gh '*|*vercel*|*netlify*|*wrangler*|*' fly '*|*flyctl*|*railway*) ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

# housekeeping (rare path — cheap): drop stale markers + old ledgers
find "${GATE_DIR}" -maxdepth 1 -name 'mark-*' -type d -mmin +10 -exec rm -rf {} + 2>/dev/null || true
find "${GATE_DIR}" -maxdepth 1 -name 'ledger-*' -mtime +1 -delete 2>/dev/null || true

# --- extract the Bash command (robust JSON parse) ---
CMD=""
if [ "${TOOL}" = "Bash" ]; then
  CMD="$(printf '%s' "${INPUT}" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get("tool_input",{}).get("command","") or "")
except Exception:
    sys.exit(7)' 2>/dev/null)"
  if [ $? -ne 0 ]; then
    # FAIL-LOUD: risky keyword present but the command could not be parsed.
    log "FAIL-LOUD parse-error session=${SESSION}"
    echo "🚦 PRE-CLAIM GATE — internal error: a risky keyword is present but the command could not be parsed. Failing closed. Append '# GLUEBOY_GATE_BYPASS=<reason>' to override (logged), or fix scripts/hooks/pre-claim-gate.sh." >&2
    exit 2
  fi
fi

# --- explicit one-shot bypass (token travels in the command text) ---
case "${CMD}" in
  *GLUEBOY_GATE_BYPASS*) log "BYPASS session=${SESSION} cmd=${CMD}"; exit 0 ;;
esac

# --- classify into a risk tier ---
# Token-based classifier (Codex review): parse the command as argv via shlex,
# not regex on the raw string. Avoids payload-text false positives (e.g.
# `gh pr create --body '...gh pr merge...'` must NOT classify as ASK-merge
# because of body text). Strips a leading `rtk` wrapper.
TIER="PASS"; LABEL=""

if [ "${TOOL}" = "TeamCreate" ]; then
  TIER="EVIDENCE"; LABEL="spawn an agent team (fan-out)"
elif [ -n "${CMD}" ]; then
  # Cheap whitespace tokenization of the first command line — robust against
  # heredoc bodies, payload quoting, and shell pipes that break shlex.
  # We only need T0..T4 to identify the verb at command position.
  FIRSTLINE="${CMD%%$'\n'*}"
  read -r T0 T1 T2 T3 T4 _ <<< "${FIRSTLINE}"
  # strip leading `rtk` wrapper
  if [ "${T0}" = "rtk" ]; then T0="${T1}"; T1="${T2}"; T2="${T3}"; T3="${T4}"; fi
  # normalize `git -C <path> <verb>` → T1=<verb>
  if [ "${T0}" = "git" ] && [ "${T1}" = "-C" ]; then T1="${T3}"; T2="${T4}"; fi
  # --prod flag anywhere in the (possibly multi-line) command
  HAS_PROD=0; case "${CMD}" in *' --prod'*|*'--prod '*|*'--prod='*) HAS_PROD=1 ;; esac

  case "${T0}" in
    gh)
      case "${T1}-${T2}" in
        pr-merge)        TIER="ASK";      LABEL="merge a pull request" ;;
        release-create)  TIER="ASK";      LABEL="publish a release" ;;
        repo-delete)     TIER="ASK";      LABEL="delete a repository" ;;
        pr-create|pr-comment)              TIER="EVIDENCE"; LABEL="open or comment on a pull request" ;;
        issue-create|issue-comment|issue-edit|issue-close) TIER="EVIDENCE"; LABEL="write to an issue" ;;
      esac
      ;;
    git)
      [ "${T1}" = "push" ] && { TIER="EVIDENCE"; LABEL="push commits"; }
      ;;
    npm)
      [ "${T1}" = "publish" ] && { TIER="ASK"; LABEL="publish an npm package"; }
      ;;
    maw)
      case "${T1}" in
        hey|talk-to|send|send-text) TIER="EVIDENCE"; LABEL="broadcast to another Oracle" ;;
      esac
      ;;
    vercel|netlify)
      if [ "${HAS_PROD}" = 1 ]; then
        TIER="ASK"; LABEL="deploy to production"
      elif [ "${T1}" = "deploy" ] || [ -z "${T1}" ]; then
        TIER="EVIDENCE"; LABEL="deploy a preview"
      fi
      ;;
    wrangler|fly|flyctl)
      [ "${T1}" = "deploy" ] && { TIER="ASK"; LABEL="deploy to production"; }
      ;;
    railway)
      [ "${T1}" = "up" ] && { TIER="ASK"; LABEL="deploy to production"; }
      ;;
  esac
fi

[ "${TIER}" = "PASS" ] && exit 0

# ===== ASK tier — irreversible / public: Captain approves =====
if [ "${TIER}" = "ASK" ]; then
  log "ASK session=${SESSION} label=${LABEL} cmd=${CMD}"
  REASON="🚦 PRE-CLAIM GATE — about to ${LABEL}. This is irreversible / public-facing, so it needs Captain approval. Before approving, confirm the claim it rests on was verified by a real check (a command that was actually run), not by prose."
  OUT="$(printf '%s' "${REASON}" | python3 -c 'import sys,json
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":sys.stdin.read()}},separators=(",",":")))' 2>/dev/null)"
  if [ -n "${OUT}" ]; then
    printf '%s\n' "${OUT}"; exit 0
  fi
  # fail-LOUD if the JSON could not be built
  echo "🚦 PRE-CLAIM GATE — ${LABEL}: approval required (gate JSON build failed; failing closed)." >&2
  exit 2
fi

# ===== EVIDENCE tier — block once; re-run passes only if a real check ran =====
# Key includes branch + HEAD so a different push target re-blocks (Codex review P2).
HEAD="$(git rev-parse HEAD 2>/dev/null || echo nohead)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo nobranch)"
# TARGET differentiates the action: command text for Bash, full-input digest for
# non-Bash tools (e.g. TeamCreate) so different spawns don't share a marker.
if [ "${TOOL}" = "Bash" ]; then
  TARGET="${CMD}"
else
  TARGET="$(printf '%s' "${INPUT}" | shasum -a 256 2>/dev/null | cut -c1-16)"
  [ -z "${TARGET}" ] && TARGET="${TOOL}-noinput"
fi
KEY="$(printf '%s' "${SESSION}|${TOOL}|${TARGET}|${BRANCH}|${HEAD}" | shasum -a 256 2>/dev/null | cut -c1-20)"
[ -z "${KEY}" ] && KEY="$(printf '%s' "${SESSION}${TARGET}" | cksum | tr -d ' ')"
MARK="${GATE_DIR}/mark-${KEY}"

if mkdir "${MARK}" 2>/dev/null; then
  # first attempt → block, snapshot the ledger length
  ledger_lines > "${MARK}/seq" 2>/dev/null || echo 0 > "${MARK}/seq"
  date +%s > "${MARK}/at" 2>/dev/null || true
  log "BLOCK-1 session=${SESSION} label=${LABEL} cmd=${CMD}"
  cat >&2 <<EOF
🚦 PRE-CLAIM GATE — about to ${LABEL}.
Before this proceeds, answer in your reasoning, then RUN the check:
  1. CLAIM    — the state / result / premise you are treating as true
  2. CHECK    — the exact command or observation that confirms it,
                from the far end or by changing one variable
  3. EVIDENCE — run that check NOW as a real tool call, then re-run this command.
A re-run with no tool call in between is blocked again. A bare ✓ is not an answer.
(Override: append  '# GLUEBOY_GATE_BYPASS=<reason>'  to the command — it is logged.)
EOF
  exit 2
fi

# marker already exists → this is a re-issue
SEQ_AT="$(cat "${MARK}/seq" 2>/dev/null || echo 0)"; SEQ_AT="${SEQ_AT//[^0-9]/}"; SEQ_AT="${SEQ_AT:-0}"
AT="$(cat "${MARK}/at" 2>/dev/null || echo 0)"; AT="${AT//[^0-9]/}"; AT="${AT:-0}"
NOW="$(date +%s)"
AGE=$(( NOW - AT ))
CUR="$(ledger_lines)"; CUR="${CUR//[^0-9]/}"; CUR="${CUR:-0}"

if [ "${CUR}" -gt "${SEQ_AT}" ] && [ "${AGE}" -ge 3 ]; then
  rm -rf "${MARK}" 2>/dev/null || true
  log "PASS session=${SESSION} label=${LABEL} ran=$(( CUR - SEQ_AT )) age=${AGE}s"
  exit 0
fi

# re-issued with nothing run during the pause (or too fresh) → block again
log "BLOCK-2 session=${SESSION} label=${LABEL} ran=$(( CUR - SEQ_AT )) age=${AGE}s"
cat >&2 <<EOF
🚦 PRE-CLAIM GATE — still blocked: re-issued to ${LABEL}, but no verifying tool call
ran during the pause (tool calls since gate: $(( CUR - SEQ_AT )), pause age: ${AGE}s).
Run your CHECK as a real command first — then re-run this. Prose is not evidence.
(Override: append  '# GLUEBOY_GATE_BYPASS=<reason>'  to the command — it is logged.)
EOF
exit 2
