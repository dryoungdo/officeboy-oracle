#!/usr/bin/env bash
# run-codex-review.sh - wrapper around Codex review-mode work.
#
# Features:
# 1. Always redirects Codex output to a file; never streams Codex through filters.
# 2. --max-runtime N, default 900s.
# 3. Monitors output-file growth; if stagnant for 300s by default, declares stuck and kills.
# 4. Documents ScheduleWakeup pairing in --help. Caller must schedule it.
# 5. Loads ~/.codex/profiles/review.toml if present, otherwise native review profiles if present.
# 6. Logs every outcome to ~/.claude/.codex-review/runs.log.
# 7. Returns 0 clean, 1 findings, 2 killed/hung/fatal.

set -u

MAX_RUNTIME=900
STAGNATION_SECONDS=300
TAIL_INTERVAL=30
TAIL_LINES=40
REPO="."
OUTPUT_FILE=""
MODE="review-uncommitted"
BASE_REF=""
COMMIT_SHA=""
PROMPT_FILE=""
SHAPE=""
NO_TAIL=0
SCOPE_ARGS=()
TEMP_CODEX_HOME=""
TEMP_PROMPT=""
PROFILE_SOURCE="default"

usage() {
  cat <<'EOF'
Usage:
  scripts/run-codex-review.sh [OPTIONS] [code|issue-body|doctrine|migration] [scope...]

Common:
  scripts/run-codex-review.sh --uncommitted --repo "$(pwd)"
  scripts/run-codex-review.sh --base origin/main --repo "$(pwd)"
  scripts/run-codex-review.sh code scripts/run-codex-review.sh scripts/test-run-codex-review.sh
  scripts/run-codex-review.sh --prompt-file /tmp/review-prompt.md --repo "$(pwd)"

Options:
  --repo DIR, -C DIR            Repo/workdir for Codex (default: .)
  --output FILE, -o FILE        Output file (default: ~/.claude/.codex-review/review-*.log)
  --max-runtime SECONDS         Hard runtime cap (default: 900)
  --stagnation-seconds SECONDS  Kill if output file does not grow (default: 300)
  --tail-interval SECONDS       How often to check/tail output (default: 30)
  --tail-lines N                Lines to show from output file on growth (default: 40)
  --no-tail                     Monitor silently
  --uncommitted                 Run codex review --uncommitted (default)
  --base REF                    Run codex review --base REF
  --commit SHA                  Run codex review --commit SHA
  --prompt-file FILE            Run codex exec with a custom prompt file
  --shape SHAPE                 One of code, issue-body, doctrine, migration
  -h, --help                    Show this help

Profile loading:
  1. If ~/.codex/profiles/review.toml exists, this wrapper copies it into a
     temporary CODEX_HOME as review.config.toml and runs `codex --profile-v2 review`.
  2. Else if ~/.codex/review.config.toml exists, it runs `codex --profile-v2 review`.
  3. Else if ~/.codex/config.toml has [profiles.review], it runs `codex --profile review`.
  4. Else it runs Codex with the default config.

ScheduleWakeup:
  When an orchestrator launches this wrapper as a hang-prone background task,
  pair that launch with ScheduleWakeup at the committed kill threshold. The
  wrapper enforces its own max runtime, but it cannot wake a parent agent that
  is waiting silently for natural completion.

Exit codes:
  0  clean review, no detected P findings
  1  findings detected, output file is useful
  2  killed, hung, or fatal Codex failure
EOF
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 2
}

is_shape() {
  case "${1:-}" in
    code|issue-body|doctrine|migration) return 0 ;;
    *) return 1 ;;
  esac
}

is_positive_integer() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) [ "$1" -gt 0 ] ;;
  esac
}

json_escape() {
  local s="${1:-}"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

file_size() {
  local file="$1"
  if [ ! -e "$file" ]; then
    printf '0'
    return
  fi
  wc -c < "$file" 2>/dev/null | tr -dc '0-9'
}

collect_descendants() {
  local parent="$1"
  local child
  pgrep -P "$parent" 2>/dev/null | while IFS= read -r child; do
    [ -n "$child" ] || continue
    printf '%s\n' "$child"
    collect_descendants "$child"
  done
}

terminate_process_tree() {
  local root_pid="$1"
  local descendants=""
  descendants="$(collect_descendants "$root_pid" 2>/dev/null || true)"

  if [ -n "$descendants" ]; then
    printf '%s\n' "$descendants" | while IFS= read -r pid; do
      [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null
    done
  fi
  kill -TERM "$root_pid" 2>/dev/null
  sleep 2
  if [ -n "$descendants" ]; then
    printf '%s\n' "$descendants" | while IFS= read -r pid; do
      [ -n "$pid" ] && kill -KILL "$pid" 2>/dev/null
    done
  fi
  kill -KILL "$root_pid" 2>/dev/null
}

log_run() {
  local status="$1"
  local exit_code="$2"
  local codex_exit="$3"
  local duration="$4"
  local findings="$5"
  local reason="$6"
  local log_dir="${HOME}/.claude/.codex-review"
  local log_file="${log_dir}/runs.log"
  local ts
  ts="$(date -Iseconds)"
  mkdir -p "$log_dir" || return
  printf '{"ts":"%s","repo":"%s","mode":"%s","shape":"%s","profile":"%s","status":"%s","exit":%s,"codex_exit":%s,"duration_s":%s,"max_runtime_s":%s,"stagnation_s":%s,"findings":%s,"reason":"%s","output_file":"%s"}\n' \
    "$(json_escape "$ts")" \
    "$(json_escape "$REPO_ABS")" \
    "$(json_escape "$MODE")" \
    "$(json_escape "${SHAPE:-}")" \
    "$(json_escape "$PROFILE_SOURCE")" \
    "$(json_escape "$status")" \
    "$exit_code" \
    "$codex_exit" \
    "$duration" \
    "$MAX_RUNTIME" \
    "$STAGNATION_SECONDS" \
    "$findings" \
    "$(json_escape "$reason")" \
    "$(json_escape "$OUTPUT_FILE")" >> "$log_file"
}

cleanup() {
  [ -n "$TEMP_PROMPT" ] && [ -f "$TEMP_PROMPT" ] && rm -f "$TEMP_PROMPT"
  [ -n "$TEMP_CODEX_HOME" ] && [ -d "$TEMP_CODEX_HOME" ] && rm -R "$TEMP_CODEX_HOME" 2>/dev/null
}
trap cleanup EXIT INT TERM

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo|-C)
      [ "$#" -ge 2 ] || die "$1 requires DIR"
      REPO="$2"
      shift 2
      ;;
    --output|-o)
      [ "$#" -ge 2 ] || die "$1 requires FILE"
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --max-runtime)
      [ "$#" -ge 2 ] || die "$1 requires SECONDS"
      is_positive_integer "$2" || die "--max-runtime must be a positive integer"
      MAX_RUNTIME="$2"
      shift 2
      ;;
    --stagnation-seconds)
      [ "$#" -ge 2 ] || die "$1 requires SECONDS"
      is_positive_integer "$2" || die "--stagnation-seconds must be a positive integer"
      STAGNATION_SECONDS="$2"
      shift 2
      ;;
    --tail-interval)
      [ "$#" -ge 2 ] || die "$1 requires SECONDS"
      is_positive_integer "$2" || die "--tail-interval must be a positive integer"
      TAIL_INTERVAL="$2"
      shift 2
      ;;
    --tail-lines)
      [ "$#" -ge 2 ] || die "$1 requires N"
      is_positive_integer "$2" || die "--tail-lines must be a positive integer"
      TAIL_LINES="$2"
      shift 2
      ;;
    --no-tail)
      NO_TAIL=1
      shift
      ;;
    --uncommitted)
      MODE="review-uncommitted"
      shift
      ;;
    --base)
      [ "$#" -ge 2 ] || die "$1 requires REF"
      MODE="review-base"
      BASE_REF="$2"
      shift 2
      ;;
    --commit)
      [ "$#" -ge 2 ] || die "$1 requires SHA"
      MODE="review-commit"
      COMMIT_SHA="$2"
      shift 2
      ;;
    --prompt-file)
      [ "$#" -ge 2 ] || die "$1 requires FILE"
      MODE="exec-prompt"
      PROMPT_FILE="$2"
      shift 2
      ;;
    --shape)
      [ "$#" -ge 2 ] || die "$1 requires SHAPE"
      is_shape "$2" || die "unknown shape: $2"
      SHAPE="$2"
      MODE="exec-template"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        SCOPE_ARGS+=("$1")
        shift
      done
      ;;
    *)
      if is_shape "$1" && [ -z "$SHAPE" ]; then
        SHAPE="$1"
        MODE="exec-template"
      else
        SCOPE_ARGS+=("$1")
      fi
      shift
      ;;
  esac
done

[ -d "$REPO" ] || die "repo dir not found: $REPO"
REPO_ABS="$(cd "$REPO" 2>/dev/null && pwd)" || die "cannot enter repo: $REPO"
REPO_NAME="$(basename "$REPO_ABS")"

LOG_DIR="${HOME}/.claude/.codex-review"
mkdir -p "$LOG_DIR" || die "cannot create log dir: $LOG_DIR"
if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="${LOG_DIR}/review-${REPO_NAME}-$(date +%Y%m%d-%H%M%S).log"
fi
OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
mkdir -p "$OUTPUT_DIR" || die "cannot create output dir: $OUTPUT_DIR"
: > "$OUTPUT_FILE" || die "cannot write output file: $OUTPUT_FILE"

CODEX_HOME_BASE="${CODEX_HOME:-${HOME}/.codex}"
CODEX_ENV_PREFIX=()
CODEX_GLOBAL_ARGS=()
if [ -f "${CODEX_HOME_BASE}/profiles/review.toml" ]; then
  TEMP_CODEX_HOME="$(mktemp -d)"
  [ -f "${CODEX_HOME_BASE}/config.toml" ] && cp "${CODEX_HOME_BASE}/config.toml" "${TEMP_CODEX_HOME}/config.toml"
  [ -f "${CODEX_HOME_BASE}/auth.json" ] && cp "${CODEX_HOME_BASE}/auth.json" "${TEMP_CODEX_HOME}/auth.json"
  cp "${CODEX_HOME_BASE}/profiles/review.toml" "${TEMP_CODEX_HOME}/review.config.toml"
  CODEX_ENV_PREFIX=(env "CODEX_HOME=${TEMP_CODEX_HOME}")
  CODEX_GLOBAL_ARGS=(--profile-v2 review)
  PROFILE_SOURCE="${CODEX_HOME_BASE}/profiles/review.toml"
elif [ -f "${CODEX_HOME_BASE}/review.config.toml" ]; then
  CODEX_GLOBAL_ARGS=(--profile-v2 review)
  PROFILE_SOURCE="${CODEX_HOME_BASE}/review.config.toml"
elif [ -f "${CODEX_HOME_BASE}/config.toml" ] && grep -q '^\[profiles\.review\]' "${CODEX_HOME_BASE}/config.toml" 2>/dev/null; then
  CODEX_GLOBAL_ARGS=(--profile review)
  PROFILE_SOURCE="${CODEX_HOME_BASE}/config.toml:[profiles.review]"
fi

build_prompt_file() {
  local template=""
  if [ -n "$PROMPT_FILE" ]; then
    [ -f "$PROMPT_FILE" ] || die "prompt file not found: $PROMPT_FILE"
    TEMP_PROMPT="$(mktemp)"
    cp "$PROMPT_FILE" "$TEMP_PROMPT"
    return
  fi

  [ -n "$SHAPE" ] || die "exec-template requires a review shape"
  if [ -f "${REPO_ABS}/.claude/skills/codex-review/templates/${SHAPE}.md" ]; then
    template="${REPO_ABS}/.claude/skills/codex-review/templates/${SHAPE}.md"
  elif [ -f "${HOME}/.claude/skills/codex-review/templates/${SHAPE}.md" ]; then
    template="${HOME}/.claude/skills/codex-review/templates/${SHAPE}.md"
  else
    die "template not found for shape: $SHAPE"
  fi

  TEMP_PROMPT="$(mktemp)"
  {
    printf 'You are reviewing repository: %s\n' "$REPO_ABS"
    if [ "${#SCOPE_ARGS[@]}" -gt 0 ]; then
      printf 'Requested scope:\n'
      printf -- '- %s\n' "${SCOPE_ARGS[@]}"
    else
      printf 'Requested scope: current working tree and recent diff.\n'
    fi
    printf '\nRules:\n'
    printf -- '- Review only. Do not modify files.\n'
    printf -- '- Inspect git diff, adjacent callers, tests, and referenced scripts/docs as needed.\n'
    printf -- '- Findings first. Use P1/P2/P3 severities with exact file/line references.\n'
    printf -- '- If clean, write exactly: CLEAN: no actionable findings in the reviewed scope.\n'
    printf '\nTemplate:\n\n'
    cat "$template"
  } > "$TEMP_PROMPT"
}

CMD=()
case "$MODE" in
  review-uncommitted)
    CMD=(codex "${CODEX_GLOBAL_ARGS[@]}" review --uncommitted)
    ;;
  review-base)
    [ -n "$BASE_REF" ] || die "--base requires REF"
    CMD=(codex "${CODEX_GLOBAL_ARGS[@]}" review --base "$BASE_REF")
    ;;
  review-commit)
    [ -n "$COMMIT_SHA" ] || die "--commit requires SHA"
    CMD=(codex "${CODEX_GLOBAL_ARGS[@]}" review --commit "$COMMIT_SHA")
    ;;
  exec-prompt|exec-template)
    build_prompt_file
    PROMPT_TEXT="$(cat "$TEMP_PROMPT")"
    CMD=(codex "${CODEX_GLOBAL_ARGS[@]}" exec --ephemeral --skip-git-repo-check -s read-only -C "$REPO_ABS" "$PROMPT_TEXT")
    ;;
  *)
    die "internal error: unknown mode $MODE"
    ;;
esac

printf '[codex-review] repo=%s mode=%s profile=%s\n' "$REPO_ABS" "$MODE" "$PROFILE_SOURCE"
printf '[codex-review] output=%s\n' "$OUTPUT_FILE"
printf '[codex-review] max_runtime=%ss stagnation=%ss tail_interval=%ss\n' "$MAX_RUNTIME" "$STAGNATION_SECONDS" "$TAIL_INTERVAL"

START_EPOCH="$(date +%s)"
(
  cd "$REPO_ABS" || exit 2
  if [ "${#CODEX_ENV_PREFIX[@]}" -gt 0 ]; then
    "${CODEX_ENV_PREFIX[@]}" "${CMD[@]}"
  else
    "${CMD[@]}"
  fi
) > "$OUTPUT_FILE" 2>&1 &
CODEX_PID=$!

LAST_SIZE="$(file_size "$OUTPUT_FILE")"
LAST_GROWTH="$START_EPOCH"
KILLED=0
KILL_REASON=""

while kill -0 "$CODEX_PID" 2>/dev/null; do
  sleep "$TAIL_INTERVAL"
  NOW="$(date +%s)"
  CURRENT_SIZE="$(file_size "$OUTPUT_FILE")"

  if [ "$CURRENT_SIZE" -gt "$LAST_SIZE" ]; then
    LAST_SIZE="$CURRENT_SIZE"
    LAST_GROWTH="$NOW"
    if [ "$NO_TAIL" -eq 0 ]; then
      printf '[codex-review] output grew to %s bytes; tail follows\n' "$CURRENT_SIZE"
      tail -n "$TAIL_LINES" "$OUTPUT_FILE" 2>/dev/null
    fi
  fi

  RUNTIME=$((NOW - START_EPOCH))
  STAGNANT_FOR=$((NOW - LAST_GROWTH))
  if [ "$RUNTIME" -ge "$MAX_RUNTIME" ]; then
    KILLED=1
    KILL_REASON="max-runtime ${MAX_RUNTIME}s exceeded"
    printf '[codex-review] STUCK: %s; killing pid %s\n' "$KILL_REASON" "$CODEX_PID" >&2
    terminate_process_tree "$CODEX_PID"
    break
  fi
  if [ "$STAGNANT_FOR" -ge "$STAGNATION_SECONDS" ]; then
    KILLED=1
    KILL_REASON="output stagnant ${STAGNANT_FOR}s"
    printf '[codex-review] STUCK: %s; killing pid %s\n' "$KILL_REASON" "$CODEX_PID" >&2
    terminate_process_tree "$CODEX_PID"
    break
  fi
done

wait "$CODEX_PID" 2>/dev/null
CODEX_EXIT=$?
END_EPOCH="$(date +%s)"
DURATION=$((END_EPOCH - START_EPOCH))

FINDINGS="$(grep -Ec '^[[:space:]]*[-*][[:space:]]*\[P[0-9]\]|^[[:space:]]*P[0-9][[:space:]:-]' "$OUTPUT_FILE" 2>/dev/null || true)"
FINDINGS="$(printf '%s' "$FINDINGS" | tr -dc '0-9')"
[ -n "$FINDINGS" ] || FINDINGS=0

if [ "$KILLED" -eq 1 ]; then
  log_run "killed" 2 "$CODEX_EXIT" "$DURATION" "$FINDINGS" "$KILL_REASON"
  printf '[codex-review] exit=2 killed reason=%s output=%s\n' "$KILL_REASON" "$OUTPUT_FILE"
  exit 2
fi

if [ "$FINDINGS" -gt 0 ]; then
  log_run "findings" 1 "$CODEX_EXIT" "$DURATION" "$FINDINGS" "P findings detected"
  printf '[codex-review] exit=1 findings=%s output=%s\n' "$FINDINGS" "$OUTPUT_FILE"
  exit 1
fi

if [ "$CODEX_EXIT" -ne 0 ]; then
  log_run "failed" 2 "$CODEX_EXIT" "$DURATION" "$FINDINGS" "codex exited non-zero without detected findings"
  printf '[codex-review] exit=2 codex_exit=%s output=%s\n' "$CODEX_EXIT" "$OUTPUT_FILE"
  exit 2
fi

log_run "clean" 0 "$CODEX_EXIT" "$DURATION" "$FINDINGS" "clean"
printf '[codex-review] exit=0 clean output=%s\n' "$OUTPUT_FILE"
exit 0
