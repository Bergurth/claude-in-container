#!/usr/bin/env bash
set -euo pipefail

# Usage: ./claude-up.sh [PATH_TO_PROJECT] [PATH_TO_PROJECT_2] [PATH_TO_PROJECT_3] ... [--security] [--name NAME] [--yolo] [--root]
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

# Default settings
NAME="claude-code"
COMPOSE_FILE="compose.yml"
SERVICE_NAME="claude"
SECURITY_MODE=0

# Parse flags
for arg in "${FLAGS[@]}"; do
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
      # Handle --name with next argument (this is simplified for the refactor)
      echo "Error: --name requires a value. Use --name=VALUE format." >&2
      exit 1
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


# Display mounted directories
echo "Mounting project directories:"
for i in "${!PROJECT_PATHS[@]}"; do
  if [[ $i -eq 0 ]]; then
    echo "  ${PROJECT_PATHS[$i]} -> /app"
  else
    echo "  ${PROJECT_PATHS[$i]} -> /app_$((i+1))"
  fi
done
echo "Using compose file: $COMPOSE_FILE"
echo "Service name: $SERVICE_NAME"

if [[ $YOLO -eq 1 ]]; then
  echo "YOLO: passing --dangerously-skip-permissions to claude CLI"
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" -it "$SERVICE_NAME" claude --dangerously-skip-permissions
else
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" -it "$SERVICE_NAME"
fi
