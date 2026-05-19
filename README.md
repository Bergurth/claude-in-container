# Claude Code Container

A containerized environment for running Anthropic's Claude Code CLI tool with proper isolation and persistent settings.

## What it does

This project provides a Docker-based setup to run Claude Code in an isolated container environment while preserving your project files and Claude settings between sessions.

## How to run

1. Build the Docker image:
   ```bash
   docker build -t claude-code-env .
   ```

2. Run Claude Code on your project:
   ```bash
   ./claude-up.sh [PATH_TO_PROJECT] [PATH_TO_PROJECT_2] [PATH_TO_PROJECT_3] ... [FLAGS]
   ```

   - If no path is provided, it uses the current directory
   - Supports up to 5 project directories simultaneously
   - Additional directories are mounted as `/app_2`, `/app_3`, etc.
   - See flags section below for available options

## Basic Features

- **Containerized Claude Code**: Runs Claude Code CLI in an isolated Ubuntu container
- **Multi-project mounting**: Your project directories are mounted to `/app`, `/app_2`, `/app_3`, etc. in the container
- **Persistent settings**: Claude settings are preserved in `~/.claude-settings` on the host
- **User permissions**: Maintains proper file ownership using your local UID/GID
- **Multiple instances**: Support for named containers with `--name` flag
- **Root mode**: Optional `--root` flag for elevated permissions
- **Playwright MCP**: Optional `--playwright` flag for web automation via MCP

## Security Features

- **Network isolation**: Uses bridge networking with NAT for outbound internet only
- **No inbound ports**: Container doesn't expose any ports to prevent external access
- **User isolation**: Runs with your local user permissions by default
- **Volume isolation**: Only mounts specified directories

## Security Concerns

- **YOLO mode**: The `--yolo` flag bypasses Claude's permission checks - use with caution
- **Root access**: The `--root` flag runs the container as root - only use when necessary
- **Project access**: The container has full access to your mounted project directory
- **Internet access**: Container has outbound internet access for Claude Code functionality
- **Settings persistence**: Claude settings are stored on the host filesystem

## Usage Examples

```bash
# Run on current directory
./claude-up.sh

# Run on specific project
./claude-up.sh /path/to/my/project

# Run with multiple projects
./claude-up.sh /path/to/project1 /path/to/project2

# Run with up to 5 projects
./claude-up.sh ~/frontend ~/backend ~/docs ~/scripts ~/config

# Combine multiple projects with flags
./claude-up.sh /path/to/project1 /path/to/project2 --name multi-dev

# Run with custom container name
./claude-up.sh --name=my-project

# Run with root permissions (use carefully)
./claude-up.sh --root

# Run in YOLO mode (bypasses permissions)
./claude-up.sh --yolo

# Multiple projects with different options
./claude-up.sh ~/django-app ~/react-frontend --name=fullstack --yolo

# Enable Playwright MCP for web automation
./claude-up.sh --playwright --name=web-testing
```

## Playwright MCP Integration

The `--playwright` flag enables web automation capabilities through the Model Context Protocol (MCP). This allows Claude to interact with web browsers for tasks like testing, scraping, and automation.

### Playwright Setup

1. **Enable Playwright MCP**:
   ```bash
   ./claude-up.sh --playwright --name=my-web-project
   ```

2. **Start Chrome with remote debugging**:
   ```bash
   ./start-chrome-debug.sh
   ```
   Or manually:
   ```bash
   chrome --remote-debugging-port=9222
   ```

3. **Configuration**: The MCP configuration is automatically created at:
   ```
   ~/.claude-settings-<name>/config/mcp.json
   ```

### Playwright Features

- **Full browser control**: Navigate, click, type, extract data
- **No screenshots needed**: Uses accessibility tree for fast, accurate interaction
- **Chrome extension support**: Connect to existing browser instances with extensions
- **Cross-platform**: Works on macOS, Linux, and Windows

### Configuration Template

The auto-generated MCP configuration (`mcp-config-template.json`):
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--cdp-endpoint=http://host.docker.internal:9222"
      ]
    }
  }
}
```

### Chrome Helper Script

Use `./start-chrome-debug.sh` to launch Chrome with remote debugging:
- **Default port**: 9222
- **Custom port**: `./start-chrome-debug.sh 9223`
- **Cross-platform**: Automatically detects Chrome installation
- **Isolated profile**: Uses temporary user data directory

### Playwright Security Notes

- **Browser access**: Playwright can control your browser and access websites
- **Remote debugging**: Chrome's remote debugging port should only be accessible locally
- **Data isolation**: Uses temporary Chrome profile by default
- **Network access**: Full internet access for web automation tasks