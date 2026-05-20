#!/usr/bin/env bash
set -euo pipefail

# Usage: ./claude-up.sh [PATH_TO_PROJECT] [PATH_TO_PROJECT_2] [PATH_TO_PROJECT_3] ... [--name NAME] [--yolo] [--root] [--playwright]
# If no PATH_TO_PROJECT specified, defaults to the current directory.
# Supports up to 5 project directories.

# Collect project paths (all non-flag arguments at the beginning)
PROJECT_PATHS=()
FLAGS=()

for arg in "$@"; do
  case "$arg" in
    --*)
      FLAGS+=("$arg")
      ;;
    *)
      if [[ ${#FLAGS[@]} -eq 0 ]]; then
        PROJECT_PATHS+=("$arg")
      else
        FLAGS+=("$arg")
      fi
      ;;
  esac
done

# If no project paths specified, use current directory
if [[ ${#PROJECT_PATHS[@]} -eq 0 ]]; then
  PROJECT_PATHS=("$(pwd)")
fi

# Limit to 5 project paths
if [[ ${#PROJECT_PATHS[@]} -gt 5 ]]; then
  echo "Error: Maximum 5 project directories supported" >&2
  exit 1
fi

# Resolve all paths to absolute paths and export
for i in "${!PROJECT_PATHS[@]}"; do
  path="${PROJECT_PATHS[$i]}"
  if [[ ! -d "$path" ]]; then
    echo "Error: Directory does not exist: $path" >&2
    exit 1
  fi
  abs_path="$(cd "$path" && pwd)"
  PROJECT_PATHS[$i]="$abs_path"

  if [[ $i -eq 0 ]]; then
    export PROJECT_ROOT="$abs_path"  # Maintain backwards compatibility
  fi
  export "PROJECT_ROOT_$((i+1))"="$abs_path"
done

# Default container name; allow --name foo or --name=foo
NAME="claude-code"
i=0
while [[ $i -lt ${#FLAGS[@]} ]]; do
  arg="${FLAGS[$i]}"
  case "$arg" in
    --name=*)
      NAME="${arg#--name=}"
      ;;
    --name)
      if [[ $((i+1)) -lt ${#FLAGS[@]} ]]; then
        NAME="${FLAGS[$((i+1))]}"
        i=$((i+1))  # Skip next argument since we consumed it
      else
        echo "Error: --name requires a value" >&2
        exit 1
      fi
      ;;
  esac
  i=$((i+1))
done

# Pick Compose (plugin or legacy)
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Docker Compose not found." >&2
  exit 1
fi


YOLO=0
ROOT_MODE=0
PLAYWRIGHT=0
USE_API_KEY=0
for arg in "${FLAGS[@]}"; do
  [[ "$arg" == "--yolo" ]] && YOLO=1
  [[ "$arg" == "--root" ]] && ROOT_MODE=1
  [[ "$arg" == "--playwright" ]] && PLAYWRIGHT=1
  [[ "$arg" == "--playwrite" ]] && PLAYWRIGHT=1  # Support common misspelling
  [[ "$arg" == "--api" ]] && USE_API_KEY=1
done

# --api flag: load key from ~/.anthropic_api_key and pass into container.
# Without this flag, sessions use OAuth (Pro quota) as normal.
if [[ $USE_API_KEY -eq 1 ]]; then
  KEY_FILE="${HOME}/.anthropic_api_key"
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    if [[ ! -f "$KEY_FILE" ]]; then
      echo "Error: --api flag set but no key found. Set ANTHROPIC_API_KEY or create ~/.anthropic_api_key" >&2
      exit 1
    fi
    ANTHROPIC_API_KEY="$(cat "$KEY_FILE")"
  fi
  export ANTHROPIC_API_KEY
  echo "API key loaded — this session will use Anthropic API billing, not Pro quota."
fi

export LOCAL_UID="$(id -u)"
export LOCAL_GID="$(id -g)"


[[ $ROOT_MODE -eq 1 ]] \
  && { export LOCAL_UID=0; export LOCAL_GID=0; } \
  || { export LOCAL_UID="$(id -u)"; export LOCAL_GID="$(id -g)"; }

# Where to persist settings on your host:
CLAUDE_SETTINGS_DIR="${CLAUDE_SETTINGS_DIR:-$HOME/.claude-settings${NAME:+-$NAME}}"
mkdir -p "$CLAUDE_SETTINGS_DIR"                 # ensure it exists
export CLAUDE_SETTINGS_DIR

# Configure Playwright MCP if flag is set
if [[ $PLAYWRIGHT -eq 1 ]]; then
  # Create project-level MCP config (where Claude Code actually looks for it)
  MCP_CONFIG="${PROJECT_ROOT}/.mcp.json"

  # Always recreate to ensure we have the latest config (but backup existing)
  if [[ -f "$MCP_CONFIG" ]]; then
    cp "$MCP_CONFIG" "${MCP_CONFIG}.backup"
  fi
  cp "$(dirname "$0")/mcp-config-template.json" "$MCP_CONFIG"
  echo "Created Playwright MCP config (host Chrome): $MCP_CONFIG"

  # Also create backup in settings for documentation
  mkdir -p "$CLAUDE_SETTINGS_DIR/config"
  cp "$MCP_CONFIG" "$CLAUDE_SETTINGS_DIR/config/mcp.json"

  # Create temporary compose file with host networking for Playwright
  TEMP_COMPOSE=$(mktemp)
  sed 's/network_mode: "bridge"/network_mode: "host"/' "$(dirname "$0")/compose.yml" > "$TEMP_COMPOSE"
  COMPOSE_FILE="$TEMP_COMPOSE"

  export PLAYWRIGHT_ENABLED=1
else
  COMPOSE_FILE="$(dirname "$0")/compose.yml"
  export PLAYWRIGHT_ENABLED=0
fi


# Display mounted directories
echo "Mounting project directories:"
for i in "${!PROJECT_PATHS[@]}"; do
  if [[ $i -eq 0 ]]; then
    echo "  ${PROJECT_PATHS[$i]} -> /app"
  else
    echo "  ${PROJECT_PATHS[$i]} -> /app_$((i+1))"
  fi
done
if [[ $PLAYWRIGHT -eq 1 ]]; then
  echo "Playwright MCP enabled - connecting to host Chrome on localhost:9222"
  echo "Make sure Chrome is running with: chrome --remote-debugging-port=9222"
fi

# Build extra args for docker compose run — only inject API key when explicitly requested.
# This guarantees ANTHROPIC_API_KEY never reaches the container in normal Pro sessions.
EXTRA_ARGS=()
if [[ $USE_API_KEY -eq 1 ]]; then
  EXTRA_ARGS+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
fi

if [[ $YOLO -eq 1 ]]; then
  echo "YOLO: passing --dangerously-skip-permissions to claude CLI"
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" "${EXTRA_ARGS[@]}" -it claude claude --dangerously-skip-permissions
else
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" "${EXTRA_ARGS[@]}" -it claude
fi
