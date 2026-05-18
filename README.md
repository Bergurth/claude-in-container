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
   ./claude-up.sh [PATH_TO_PROJECT] [PATH_TO_PROJECT_2] [PATH_TO_PROJECT_3] ...
   ```

   - If no path is provided, it uses the current directory
   - Supports up to 5 project directories simultaneously
   - Additional directories are mounted as `/app_2`, `/app_3`, etc.

## Basic Features

- **Containerized Claude Code**: Runs Claude Code CLI in an isolated Ubuntu container
- **Multi-project mounting**: Your project directories are mounted to `/app`, `/app_2`, `/app_3`, etc. in the container
- **Persistent settings**: Claude settings are preserved in `~/.claude-settings` on the host
- **User permissions**: Maintains proper file ownership using your local UID/GID
- **Multiple instances**: Support for named containers with `--name` flag
- **Root mode**: Optional `--root` flag for elevated permissions

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
./claude-up.sh /path/to/project1 /path/to/project2 --security

# Run with custom container name
./claude-up.sh --name my-project

# Run with root permissions (use carefully)
./claude-up.sh --root

# Run in YOLO mode (bypasses permissions)
./claude-up.sh --yolo

# Multiple projects with security mode
./claude-up.sh ~/web-app ~/api-server --security --name security-audit
```