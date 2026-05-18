#!/usr/bin/env bash
set -euo pipefail

# Usage: ./claude-up.sh [PATH_TO_PROJECT] [PATH_TO_PROJECT_2] [PATH_TO_PROJECT_3] ... [--name NAME] [--yolo] [--root]
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
for arg in "${FLAGS[@]}"; do
  case "$arg" in
    --name=*)
      NAME="${arg#--name=}"
      ;;
    --name)
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


YOLO=0
ROOT_MODE=0
for arg in "${FLAGS[@]}"; do
  [[ "$arg" == "--yolo" ]] && YOLO=1
  [[ "$arg" == "--root" ]] && ROOT_MODE=1
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
if [[ $YOLO -eq 1 ]]; then
  echo "YOLO: passing --dangerously-skip-permissions to claude CLI"
  exec $COMPOSE -f compose.yml run --rm --name "$NAME" -it claude claude --dangerously-skip-permissions
else
  exec $COMPOSE -f compose.yml run --rm --name "$NAME" -it claude
fi
