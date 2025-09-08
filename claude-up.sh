#!/usr/bin/env bash
set -euo pipefail

# Usage: ./claude-up.sh [PATH_TO_PROJECT]
# If omitted, defaults to the current directory.

PROJECT_INPUT="${1:-$(pwd)}"
# Resolve to absolute path
PROJECT_ROOT="$(cd "$PROJECT_INPUT" && pwd)"
export PROJECT_ROOT

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
for a in "$@"; do
  [[ "$a" == "--yolo" ]] && YOLO=1 && break
done

export LOCAL_UID="$(id -u)"
export LOCAL_GID="$(id -g)"

[ "${2-}" = "--root" ] \
  && { export LOCAL_UID=0; export LOCAL_GID=0; } \
  || { export LOCAL_UID="$(id -u)"; export LOCAL_GID="$(id -g)"; }

# Where to persist settings on your host:
CLAUDE_SETTINGS_DIR="${CLAUDE_SETTINGS_DIR:-$HOME/.claude-settings}"
mkdir -p "$CLAUDE_SETTINGS_DIR"                 # ensure it exists
export CLAUDE_SETTINGS_DIR


echo "Mounting: $PROJECT_ROOT -> /app"
if [[ $YOLO -eq 1 ]]; then
  echo "YOLO: passing --dangerously-skip-permissions to claude CLI"
  exec $COMPOSE -f compose.yml run --rm --name claude-code -it claude claude --dangerously-skip-permissions
else
  exec $COMPOSE -f compose.yml run --rm --name claude-code -it claude
fi
