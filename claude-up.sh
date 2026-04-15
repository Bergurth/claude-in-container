#!/usr/bin/env bash
set -euo pipefail

# Usage: ./claude-up.sh [PATH_TO_PROJECT] [--security] [--name NAME] [--yolo] [--root]
# If PATH_TO_PROJECT omitted, defaults to the current directory.

PROJECT_INPUT="${1:-$(pwd)}"
# Resolve to absolute path
PROJECT_ROOT="$(cd "$PROJECT_INPUT" && pwd)"
export PROJECT_ROOT

# Default settings
NAME="claude-code"
COMPOSE_FILE="compose.yml"
SERVICE_NAME="claude"
SECURITY_MODE=0

# Parse all arguments for flags
for ((i=1; i<=$#; i++)); do
  eval "arg=\${$i}"
  case "$arg" in
    --security)
      SECURITY_MODE=1
      COMPOSE_FILE="compose.security.yml"
      SERVICE_NAME="claude-sec"
      NAME="claude-code-sec"
      ;;
    --name=*)
      NAME="${arg#--name=}"
      ;;
    --name)
      j=$((i+1)); eval "NAME=\${$j-}"
      ;;
  esac
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


# Security-specific environment setup
if [[ $SECURITY_MODE -eq 1 ]]; then
    # Create security directories
    SECURITY_RESULTS_DIR="${SECURITY_RESULTS_DIR:-$PWD/security-results}"
    WORDLISTS_DIR="${WORDLISTS_DIR:-$PWD/wordlists}"
    mkdir -p "$SECURITY_RESULTS_DIR" "$WORDLISTS_DIR"
    export SECURITY_RESULTS_DIR WORDLISTS_DIR

    echo "Security mode enabled"
    echo "Results will be saved to: $SECURITY_RESULTS_DIR"
fi

YOLO=0
ROOT_MODE=0
for a in "$@"; do
  [[ "$a" == "--yolo" ]] && YOLO=1
  [[ "$a" == "--root" ]] && ROOT_MODE=1
done

export LOCAL_UID="$(id -u)"
export LOCAL_GID="$(id -g)"

[[ $ROOT_MODE -eq 1 ]] \
  && { export LOCAL_UID=0; export LOCAL_GID=0; } \
  || { export LOCAL_UID="$(id -u)"; export LOCAL_GID="$(id -g)"; }

# Where to persist settings on your host:
CLAUDE_SETTINGS_DIR="${CLAUDE_SETTINGS_DIR:-$HOME/.claude-settings${NAME:+-$NAME}}"
mkdir -p "$CLAUDE_SETTINGS_DIR"                 # ensure it exists
export CLAUDE_SETTINGS_DIR


echo "Mounting: $PROJECT_ROOT -> /app"
echo "Using compose file: $COMPOSE_FILE"
echo "Service name: $SERVICE_NAME"

if [[ $YOLO -eq 1 ]]; then
  echo "YOLO: passing --dangerously-skip-permissions to claude CLI"
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" -it "$SERVICE_NAME" claude --dangerously-skip-permissions
else
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" -it "$SERVICE_NAME"
fi
