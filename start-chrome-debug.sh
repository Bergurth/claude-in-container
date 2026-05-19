#!/usr/bin/env bash
set -euo pipefail

# Helper script to start Chrome with remote debugging for Playwright MCP
# Usage: ./start-chrome-debug.sh [PORT]

PORT=${1:-9222}

echo "Starting Chrome with remote debugging on port $PORT..."

# Detect OS and Chrome path
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    CHROME_PATH=$(which google-chrome || which chromium-browser || which chrome || echo "")
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    CHROME_PATH="$PROGRAMFILES/Google/Chrome/Application/chrome.exe"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

if [[ ! -x "$CHROME_PATH" ]]; then
    echo "Chrome not found at: $CHROME_PATH"
    echo "Please install Chrome or specify the correct path."
    exit 1
fi

echo "Found Chrome at: $CHROME_PATH"

# Start Chrome with remote debugging
exec "$CHROME_PATH" \
    --remote-debugging-port=$PORT \
    --remote-debugging-address=0.0.0.0 \
    --disable-web-security \
    --disable-features=VizDisplayCompositor \
    --user-data-dir=/tmp/chrome-debug-profile-$PORT \
    "$@"