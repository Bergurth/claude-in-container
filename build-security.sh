#!/usr/bin/env bash
set -euo pipefail

echo "Building Claude Code Security Container..."

# Check if user wants minimal version
if [[ "${1:-}" == "--minimal" ]]; then
    echo "Building minimal security image (no Go tools)..."
    docker build -f Dockerfile.security.minimal -t claude-code-sec .
else
    echo "Building full security image (includes Go tools)..."
    echo "This may take several minutes due to security tool downloads..."
    docker build -f Dockerfile.security -t claude-code-sec .
fi

echo ""
echo "Build complete! Security image 'claude-code-sec' is ready."
echo ""
echo "Usage examples:"
echo "  ./claude-up.sh --security              # Run in security mode"
echo "  ./claude-up.sh /path/to/project --security  # Run on specific project"
echo "  ./claude-up.sh --security --name pentest    # Run with custom name"
echo ""
echo "Security tools included:"
echo "  - nmap, masscan (network scanning)"
echo "  - gobuster, ffuf, nikto (web security)"
echo "  - subfinder, httpx, nuclei (modern tools)"
echo "  - hashcat, john (password tools)"
echo "  - binwalk, foremost (forensics)"
echo ""
echo "Results will be saved to ./security-results/"
echo "Wordlists available at ./wordlists/"