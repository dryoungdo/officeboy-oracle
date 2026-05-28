#!/bin/bash
# OFFICEBOY-oracle Discord wire - canonical start script
# Cloned from DEVBOY's start.sh pattern
set -u
cd /home/drdo/Code/github.com/dryoungdo/officeboy-oracle || exit 1

DISCORD_MCP_SERVER="plugin:discord:discord"

discord_mcp_connected() {
  claude mcp list 2>&1 | grep -F "$DISCORD_MCP_SERVER" | grep -Fq "Connected"
}

listener_has_discord_mcp_child() {
  local listener_pid="$1"
  local process_tree

  if command -v pstree >/dev/null 2>&1; then
    process_tree="$(pstree -pnal "$listener_pid" 2>/dev/null || true)"
    [[ "$process_tree" =~ bun.*discord || "$process_tree" =~ discord.*server[.]ts ]]
    return
  fi

  if command -v pgrep >/dev/null 2>&1 && command -v ps >/dev/null 2>&1; then
    descendant_has_discord_mcp_child "$listener_pid"
    return
  fi

  echo "[gate_hook] WARN: cannot verify Discord MCP child; pstree/pgrep/ps unavailable" >&2
  return 1
}

descendant_has_discord_mcp_child() {
  local parent_pid="$1"
  local child_pid
  local child_args

  while IFS= read -r child_pid; do
    [ -n "$child_pid" ] || continue

    child_args="$(ps -p "$child_pid" -o args= 2>/dev/null || true)"
    if [[ "$child_args" =~ bun.*discord || "$child_args" =~ discord.*server[.]ts ]]; then
      return 0
    fi

    if descendant_has_discord_mcp_child "$child_pid"; then
      return 0
    fi
  done < <(pgrep -P "$parent_pid" 2>/dev/null)

  return 1
}

discord_mcp_healthy() {
  local listener_pid="$1"

  discord_mcp_connected && listener_has_discord_mcp_child "$listener_pid"
}

stop_listener_after_health_failure() {
  local listener_pid="$1"

  if kill -0 "$listener_pid" 2>/dev/null; then
    kill -TERM "$listener_pid" 2>/dev/null || true
  fi
}

verify_discord_mcp_after_launch() {
  local listener_pid="$1"

  sleep 12

  if discord_mcp_healthy "$listener_pid"; then
    echo "[gate_hook] OK: Discord MCP connected after 12s"
    return 0
  fi

  echo "[gate_hook] WARN: Discord MCP not connected after 12s, retrying..." >&2
  sleep 5

  if discord_mcp_healthy "$listener_pid"; then
    echo "[gate_hook] OK: Discord MCP connected on retry"
    return 0
  fi

  echo "[gate_hook] ERROR: Discord MCP failed to connect after retry. OFFICEBOY is deaf." >&2
  stop_listener_after_health_failure "$listener_pid"
  exit 1
}

export DISCORD_STATE_DIR="/home/drdo/.claude/channels/discord/officeboy"

patch_discord_plugin_env() {
  local candidate
  local found=0
  local tmp=""

  if ! command -v jq >/dev/null 2>&1; then
    echo "[start.sh] WARNING: jq not found; skipping Discord plugin .mcp.json env patch" >&2
    return 0
  fi

  for candidate in "$HOME"/.claude/plugins/cache/claude-plugins-official/discord/*/.mcp.json; do
    [ -f "$candidate" ] || continue
    found=1

    if jq -e --arg dir "$DISCORD_STATE_DIR" \
      '.mcpServers.discord.env.DISCORD_STATE_DIR == $dir' \
      "$candidate" >/dev/null 2>&1; then
      echo "[start.sh] Discord plugin env.DISCORD_STATE_DIR already correct in $candidate" >&2
      continue
    fi

    echo "[start.sh] Patching $candidate with DISCORD_STATE_DIR=$DISCORD_STATE_DIR" >&2

    if ! tmp="$(mktemp)"; then
      echo "[start.sh] WARNING: failed to create temp file; skipping patch for $candidate" >&2
      continue
    fi

    if jq --arg dir "$DISCORD_STATE_DIR" \
      '.mcpServers.discord.env = (.mcpServers.discord.env // {}) * {DISCORD_STATE_DIR: $dir}' \
      "$candidate" > "$tmp" && mv "$tmp" "$candidate"; then
      echo "[start.sh] Patched $candidate" >&2
    else
      echo "[start.sh] WARNING: failed to patch $candidate" >&2
      rm -f "$tmp"
    fi
    tmp=""
  done

  if [ "$found" -eq 0 ]; then
    echo "[start.sh] WARNING: Discord plugin .mcp.json not found; skipping env patch" >&2
  fi
}

patch_discord_plugin_env

has_prior_session() {
  local encoded_pwd
  encoded_pwd=$(echo "$(pwd)" | sed 's|^/|-|; s|[/.]|-|g')
  local project_dir="$HOME/.claude/projects/${encoded_pwd}"
  [ -d "$project_dir" ] && ls "$project_dir"/*.jsonl >/dev/null 2>&1
}

CLAUDE_ARGS=(
  --model claude-opus-4-8
  --dangerously-skip-permissions
  --channels plugin:discord@claude-plugins-official
)
if { [ "${CLAUDE_CONTINUE:-0}" = "1" ] || [ "${1:-}" = "--continue" ]; } && has_prior_session; then
  CLAUDE_ARGS+=(--continue)
elif [ "${CLAUDE_CONTINUE:-0}" = "1" ]; then
  echo "[start.sh] No prior session found — starting fresh (ignoring CLAUDE_CONTINUE)" >&2
fi

verify_discord_mcp_after_launch "$$" &

exec claude "${CLAUDE_ARGS[@]}"
