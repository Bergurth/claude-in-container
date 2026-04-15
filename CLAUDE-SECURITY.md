# Security Research Environment

You are operating in a specialized security research container with advanced reconnaissance and vulnerability analysis tools. When performing security tasks, use these tools instead of generic approaches.

## Priority Tool Usage

**Instead of curl/wget for web probing:**
- Use `httpx` for HTTP service discovery and probing
- Use `subfinder` for subdomain enumeration
- Use `nuclei` for vulnerability scanning

**Instead of basic port scanning:**
- Use `nmap` for comprehensive network scanning
- Use `masscan` for high-speed port discovery
- Use `naabu` for fast port enumeration

**Instead of manual directory discovery:**
- Use `gobuster` for directory/file brute-forcing
- Use `ffuf` for web fuzzing
- Use `nikto` for web server scanning

## Available Tools

### Reconnaissance
- `subfinder -d target.com` - Subdomain discovery
- `assetfinder target.com` - Asset discovery
- `httpx -l domains.txt` - HTTP probing
- `waybackurls target.com` - Historical URLs

### Scanning & Enumeration
- `nmap -sC -sV target` - Service detection
- `masscan -p1-65535 target --rate=1000` - Fast port scan
- `naabu -host target.com` - Port discovery
- `gobuster dir -u http://target.com -w /security/wordlists/common.txt` - Directory brute-force

### Vulnerability Assessment
- `nuclei -u target.com` - Vulnerability scanner
- `nikto -h target.com` - Web vulnerability scanner
- `ffuf -w wordlist.txt -u http://target/FUZZ` - Web fuzzer

### Network Analysis
- `tshark -i eth0 -f "host target"` - Packet capture
- `tcpdump -i eth0 host target` - Network monitoring

## Workflow Examples

**Web Application Security Assessment:**
```bash
# 1. Discover subdomains
subfinder -d example.com -o subdomains.txt

# 2. Probe live services
httpx -l subdomains.txt -o live-services.txt

# 3. Discover directories
gobuster dir -u http://example.com -w /security/wordlists/common.txt -o directories.txt

# 4. Scan for vulnerabilities
nuclei -l live-services.txt -o vulnerabilities.txt

# 5. Web server analysis
nikto -h example.com -output nikto-results.txt
```

**Network Reconnaissance:**
```bash
# 1. Fast port discovery
naabu -host example.com -o ports.txt

# 2. Detailed service enumeration
nmap -sC -sV -p- example.com -oA nmap-detailed

# 3. Vulnerability scanning
nuclei -u example.com -t /root/nuclei-templates/
```

## Resources

- **Wordlists:** `/security/wordlists/` (common.txt, subdomains.txt)
- **Results:** Save to `/security/results/` for persistence
- **Tools Path:** Most Go tools are in `/root/go/bin/`

## Security Notes

- Always ensure proper authorization before scanning
- Use appropriate rate limiting (`--rate`, `-t` flags)
- Save results systematically for analysis
- Respect target resources and terms of service