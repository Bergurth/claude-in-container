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
   ./claude-up.sh [PATH_TO_PROJECT]
   ```

   If no path is provided, it uses the current directory.

## Basic Features

- **Containerized Claude Code**: Runs Claude Code CLI in an isolated Ubuntu container
- **Project mounting**: Your project directory is mounted to `/app` in the container
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

# Run with custom container name
./claude-up.sh --name my-project

# Run with root permissions (use carefully)
./claude-up.sh --root

# Run in YOLO mode (bypasses permissions)
./claude-up.sh --yolo
```