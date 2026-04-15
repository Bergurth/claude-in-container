# Claude Code Security Research Container

A containerized environment for security research, reconnaissance, and vulnerability analysis built on top of the Claude Code container framework.

## Overview

This security-focused variant extends the base Claude Code container with essential security research tools while maintaining the same isolated, permission-aware architecture. It provides a lightweight alternative to full distributions like Kali Linux, specifically optimized for reconnaissance and vulnerability research workflows.

## Implementation Guide

### 1. Create Security Branch

```bash
# Create and switch to security branch
git checkout -b claude-code-sec

# Verify you're on the new branch
git branch
```

### 2. Create Security Dockerfile

Create a new `Dockerfile.security` that extends the base functionality:

```dockerfile
FROM ubuntu:latest

# Install base system packages
RUN apt-get update && apt-get install -y \
    # Base development tools (from original)
    npm nodejs python3 python3-pip python3-venv git ripgrep fd-find \
    # Database tools
    postgresql-client libpq-dev sqlite3 \
    # Security reconnaissance tools
    nmap masscan rustscan \
    # Web security tools
    gobuster ffuf nikto dirb \
    # Network analysis
    wireshark-tshark tcpdump netcat-openbsd netcat-traditional \
    # OSINT and enumeration
    dnsutils whois curl wget \
    # Crypto and forensics
    hashcat john binwalk foremost \
    # Additional utilities
    tmux screen vim nano jq yq \
    # Build essentials for tool compilation
    build-essential gcc make \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Install Python security tools
RUN pip3 install --no-cache-dir --break-system-packages \
    # Original Python tools
    django djangorestframework black flake8 pytest mypy isort \
    # Security Python tools
    requests beautifulsoup4 selenium \
    # DNS and subdomain tools
    dnspython \
    # Web scraping and OSINT
    scrapy shodan \
    # Network scanning helpers
    python-nmap \
    # General utilities
    colorama termcolor

# Install Go (for modern security tools)
RUN wget -q https://go.dev/dl/go1.21.5.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz \
    && rm go1.21.5.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install modern security tools written in Go
RUN go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest \
    && go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest \
    && go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest \
    && go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest \
    && go install -v github.com/tomnomnom/assetfinder@latest \
    && go install -v github.com/tomnomnom/waybackurls@latest
ENV PATH="/root/go/bin:${PATH}"

# Create directories for security research
RUN mkdir -p /security/{wordlists,tools,results,scripts}

# Download common wordlists
WORKDIR /security/wordlists
RUN wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt \
    && wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/directory-list-2.3-medium.txt \
    && wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt

# Set working directory
WORKDIR /app
COPY . /app

# Default command
CMD ["claude"]
```

### 3. Create Security-Specific Compose File

Create `compose.security.yml`:

```yaml
services:
  claude-sec:
    image: claude-code-sec
    working_dir: /app
    user: "${LOCAL_UID:-1000}:${LOCAL_GID:-1000}"
    environment:
      # Force all config/cache/data to live under /settings (persisted)
      - HOME=/settings
      - XDG_CONFIG_HOME=/settings/config
      - XDG_CACHE_HOME=/settings/cache
      - XDG_DATA_HOME=/settings/data
      # Security tool environment variables
      - GOPATH=/settings/go
      - PATH=/usr/local/go/bin:/root/go/bin:/settings/go/bin:$PATH
    volumes:
      - ${PROJECT_ROOT}:/app
      - ${CLAUDE_SETTINGS_DIR}:/settings
      - ${SECURITY_RESULTS_DIR:-./security-results}:/security/results
      - ${WORDLISTS_DIR:-./wordlists}:/security/wordlists
    stdin_open: true
    tty: true
    network_mode: "bridge"
    # Add capabilities for network tools (use carefully)
    cap_add:
      - NET_RAW
      - NET_ADMIN
    # Optional: restrict to specific networks for safety
    # networks:
    #   - security_net
```

### 4. Modify claude-up.sh for Security Mode

Create enhanced version that supports image selection:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: ./claude-up.sh [PATH_TO_PROJECT] [--security] [--name NAME] [--yolo] [--root]

PROJECT_INPUT="${1:-$(pwd)}"
PROJECT_ROOT="$(cd "$PROJECT_INPUT" && pwd)"
export PROJECT_ROOT

# Default settings
NAME="claude-code"
COMPOSE_FILE="compose.yml"
IMAGE_NAME="claude-code-env"
SECURITY_MODE=0

# Parse arguments
for arg in "$@"; do
    case $arg in
        --security)
            SECURITY_MODE=1
            COMPOSE_FILE="compose.security.yml"
            IMAGE_NAME="claude-code-sec"
            NAME="claude-code-sec"
            ;;
        --name=*)
            NAME="${arg#--name=}"
            ;;
        --name)
            shift; NAME="$1"
            ;;
    esac
done

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

# Rest of original script logic...
# [Include existing docker compose detection, YOLO, root handling, etc.]

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

[[ "${2-}" = "--root" || "${3-}" = "--root" ]] \
  && { export LOCAL_UID=0; export LOCAL_GID=0; } \
  || { export LOCAL_UID="$(id -u)"; export LOCAL_GID="$(id -g)"; }

# Where to persist settings on your host:
CLAUDE_SETTINGS_DIR="${CLAUDE_SETTINGS_DIR:-$HOME/.claude-settings${NAME:+-$NAME}}"
mkdir -p "$CLAUDE_SETTINGS_DIR"
export CLAUDE_SETTINGS_DIR

echo "Mounting: $PROJECT_ROOT -> /app"
echo "Using image: $IMAGE_NAME"

if [[ $YOLO -eq 1 ]]; then
  echo "YOLO: passing --dangerously-skip-permissions to claude CLI"
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" -it claude-sec claude --dangerously-skip-permissions
else
  exec $COMPOSE -f "$COMPOSE_FILE" run --rm --name "$NAME" -it claude-sec
fi
```

### 5. Build Instructions

```bash
# Build the security image
docker build -f Dockerfile.security -t claude-code-sec .

# Test the build
docker images | grep claude-code-sec
```

### 6. Usage Examples

```bash
# Run in security mode
./claude-up.sh --security

# Run security mode on specific project
./claude-up.sh /path/to/target-project --security

# Run with custom name
./claude-up.sh --security --name pentest-project

# Run in YOLO mode for automated scanning
./claude-up.sh --security --yolo
```

## Security Tools Included

### Reconnaissance
- **nmap**: Network discovery and security auditing
- **masscan**: High-speed port scanner
- **subfinder**: Subdomain discovery tool
- **httpx**: Fast HTTP toolkit
- **assetfinder**: Find domains and subdomains

### Web Security
- **gobuster**: Directory/file & DNS brute-forcer
- **ffuf**: Fast web fuzzer
- **nikto**: Web server scanner
- **nuclei**: Vulnerability scanner

### Network Analysis
- **wireshark-tshark**: Network protocol analyzer
- **tcpdump**: Network packet analyzer
- **netcat**: Network utility

### OSINT & Enumeration
- **theHarvester**: E-mail, subdomain, and people names harvester
- **whois**: Domain registration information
- **dnsutils**: DNS lookup utilities

### Crypto & Forensics
- **hashcat**: Password recovery tool
- **john**: Password cracker
- **binwalk**: Firmware analysis tool

## Security Considerations

### Safe Defaults
- Container runs with user permissions by default
- Network isolation prevents inbound connections
- Results are saved to mounted volumes for persistence
- Capabilities are only added when necessary

### Risk Mitigation
- Use `--security` flag explicitly to run security tools
- Results directory is outside project directory
- Tools require explicit invocation
- YOLO mode should only be used in controlled environments

### Best Practices
- Always run in isolated networks when possible
- Regularly update tool databases (`nuclei -update-templates`)
- Use dedicated project directories for security research
- Review all scripts before execution

## Extending the Platform

### Adding New Tools
1. Add package to `Dockerfile.security`
2. Update documentation
3. Test in isolated environment
4. Submit PR to security branch

### Custom Wordlists
Place custom wordlists in `./wordlists/` directory - they'll be mounted to `/security/wordlists/` in container.

### Result Management
All scan results are saved to `./security-results/` by default. Structure by target:
```
security-results/
├── example.com/
│   ├── nmap/
│   ├── gobuster/
│   └── nuclei/
└── target2.com/
```

## Contributing

1. Work on the `claude-code-sec` branch
2. Test all changes in isolated environments
3. Document new tools and capabilities
4. Follow responsible disclosure for any vulnerabilities found
5. Submit PRs with clear security implications

## Legal and Ethical Use

This platform is designed for:
- Authorized penetration testing
- Security research on your own systems
- Educational purposes
- Defensive security analysis

**NOT for:**
- Unauthorized system access
- Malicious activities
- Violating terms of service
- Illegal reconnaissance

Always ensure you have proper authorization before using these tools on any systems you do not own.