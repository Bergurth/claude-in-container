# Claude Code Container

A containerized environment for running Anthropic's Claude Code CLI tool with proper isolation and persistent settings.

## What it does

This project provides a Docker-based setup to run Claude Code in an isolated container environment while preserving your project files and Claude settings between sessions.

## How to run

1. Build the security image:
   ```bash
   ./build-security.sh          # full image with Go tools
   ./build-security.sh --minimal  # lighter image, no Go tools
   ```

2. Run Claude Code on your project:
   ```bash
   ./claude-up.sh [PATH_TO_PROJECT] [PATH_TO_PROJECT_2] ... [FLAGS]
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
- **Playwright MCP**: Optional `--playwright` flag for browser automation via MCP
- **API key mode**: Optional `--api` flag for Anthropic API billing instead of Pro quota
- **Pipeline mode**: Optional `--prompt-file PATH` for non-interactive automation

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

# Security mode (uses claude-code-sec image + security tools)
./claude-up.sh --security

# Multiple projects with security mode
./claude-up.sh ~/web-app ~/api-server --security --name security-audit

# Run with custom container name (= and space forms both work)
./claude-up.sh --name=my-project
./claude-up.sh --name my-project

# Run with root permissions (use carefully)
./claude-up.sh --root

# Run in YOLO mode (bypasses permissions)
./claude-up.sh --yolo

# Enable Playwright MCP for web automation
./claude-up.sh --playwright

# Playwright + security mode (host networking applied to security compose file)
./claude-up.sh --security --playwright

# Use Anthropic API billing instead of Pro quota
./claude-up.sh --api

# Non-interactive pipeline mode (runs prompt and exits)
./claude-up.sh --prompt-file /path/to/prompt.md

# Pipeline with API key and budget cap
./claude-up.sh --prompt-file /path/to/prompt.md --api
MAX_BUDGET_USD=0.50 ./claude-up.sh --prompt-file /path/to/prompt.md --api

# Pipeline in security mode
./claude-up.sh --security --prompt-file /path/to/audit-prompt.md --api
```

## Playwright MCP Integration

The `--playwright` flag enables browser automation through the Model Context Protocol (MCP),
connecting Claude to a Chrome instance running with remote debugging on the host.

### Setup

1. Start Chrome with remote debugging:
   ```bash
   ./start-chrome-debug.sh
   # or manually:
   chrome --remote-debugging-port=9222
   ```

2. Launch with Playwright enabled:
   ```bash
   ./claude-up.sh --playwright
   ```

The script writes `.mcp.json` to your project root (backed up if already present) and
switches the container to host networking so it can reach `localhost:9222`.

When combined with `--security`, host networking is applied to `compose.security.yml`
so all security-specific volumes and capabilities are preserved.

## API Key Mode (`--api`)

By default all sessions use OAuth/Pro quota and **no API key enters the container**.
The `--api` flag explicitly opts a session into Anthropic API billing:

- Reads the key from `~/.anthropic_api_key` or `$ANTHROPIC_API_KEY`
- Injects it via `-e` only for that session
- Prints a warning so you know the session is billed

```bash
echo "sk-ant-api03-..." > ~/.anthropic_api_key
./claude-up.sh --api
```

## Pipeline Mode (`--prompt-file`)

Run a prompt non-interactively and exit — useful in CI/CD or scripted workflows:

```bash
./claude-up.sh --prompt-file ./prompts/audit.md --security --api
```

- Prompt file content is passed to Claude via `-p`
- Session persistence is disabled (`--no-session-persistence`)
- Combine with `MAX_BUDGET_USD` env var to cap spend
- `security-claude-wrapper.sh` is intentionally bypassed in pipeline mode