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

# Multi-oracle Discord fix: each oracle gets its own plugin cache copy
# so patching .mcp.json doesn't clobber sibling oracles on the same machine.
ORACLE_NAME="officeboy"
SHARED_CACHE="$HOME/.claude/plugins/cache/claude-plugins-official/discord"
LOCAL_CACHE="$HOME/.claude/plugins/cache/discord-${ORACLE_NAME}"

setup_local_plugin_cache() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "[start.sh] WARNING: jq not found; skipping local plugin cache setup" >&2
    return 0
  fi

  local latest_version
  latest_version=$(ls -d "${SHARED_CACHE}"/*/  2>/dev/null | sort -V | tail -1)
  if [ -z "$latest_version" ]; then
    echo "[start.sh] WARNING: no shared Discord plugin found; skipping" >&2
    return 0
  fi

  local version_name
  version_name=$(basename "$latest_version")
  local local_version_dir="${LOCAL_CACHE}/discord/${version_name}"

  if [ ! -d "$local_version_dir" ]; then
    echo "[start.sh] Creating local plugin cache: $local_version_dir" >&2
    mkdir -p "$local_version_dir"
    cp -a "${latest_version}/." "$local_version_dir/"
  fi

  local mcp_json="${local_version_dir}/.mcp.json"
  if [ -f "$mcp_json" ]; then
    local tmp
    tmp=$(mktemp) || return 0
    if jq --arg dir "$DISCORD_STATE_DIR" \
      '.mcpServers.discord.env = (.mcpServers.discord.env // {}) * {DISCORD_STATE_DIR: $dir}' \
      "$mcp_json" > "$tmp" && mv "$tmp" "$mcp_json"; then
      echo "[start.sh] Patched local .mcp.json with DISCORD_STATE_DIR=$DISCORD_STATE_DIR" >&2
    else
      rm -f "$tmp"
    fi
  fi
}

setup_local_plugin_cache

has_prior_session() {
  local encoded_pwd
  encoded_pwd=$(echo "$(pwd)" | sed 's|^/|-|; s|[/.]|-|g')
  local project_dir="$HOME/.claude/projects/${encoded_pwd}"
  [ -d "$project_dir" ] && ls "$project_dir"/*.jsonl >/dev/null 2>&1
}

patch_shared_plugin_env() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "[start.sh] WARNING: jq not found; skipping shared plugin env patch" >&2
    return 0
  fi

  local candidate found=0 tmp=""
  for candidate in "$SHARED_CACHE"/*/.mcp.json; do
    [ -f "$candidate" ] || continue
    found=1

    if jq -e --arg dir "$DISCORD_STATE_DIR" \
      '.mcpServers.discord.env.DISCORD_STATE_DIR == $dir' \
      "$candidate" >/dev/null 2>&1; then
      continue
    fi

    tmp=$(mktemp) || continue
    if jq --arg dir "$DISCORD_STATE_DIR" \
      '.mcpServers.discord.env = (.mcpServers.discord.env // {}) * {DISCORD_STATE_DIR: $dir}' \
      "$candidate" > "$tmp" && mv "$tmp" "$candidate"; then
      echo "[start.sh] Patched shared $candidate with DISCORD_STATE_DIR=$DISCORD_STATE_DIR" >&2
    else
      rm -f "$tmp"
    fi
    tmp=""
  done
}

# Use local plugin cache if it exists; fall back to shared (with env patch)
if [ -d "$LOCAL_CACHE/discord" ]; then
  DISCORD_CHANNEL_FLAG="plugin:discord@discord-${ORACLE_NAME}"
  echo "[start.sh] Using local Discord plugin cache: $LOCAL_CACHE" >&2
else
  patch_shared_plugin_env
  DISCORD_CHANNEL_FLAG="plugin:discord@claude-plugins-official"
  echo "[start.sh] Using shared Discord plugin cache (patched env)" >&2
fi

CLAUDE_ARGS=(
  --model claude-opus-4-6
  --dangerously-skip-permissions
  --channels "$DISCORD_CHANNEL_FLAG"
)
if { [ "${CLAUDE_CONTINUE:-0}" = "1" ] || [ "${1:-}" = "--continue" ]; } && has_prior_session; then
  CLAUDE_ARGS+=(--continue)
elif [ "${CLAUDE_CONTINUE:-0}" = "1" ]; then
  echo "[start.sh] No prior session found — starting fresh (ignoring CLAUDE_CONTINUE)" >&2
fi

verify_discord_mcp_after_launch "$$" &

exec claude "${CLAUDE_ARGS[@]}"
