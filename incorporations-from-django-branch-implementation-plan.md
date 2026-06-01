# Incorporating django-claude Features into claude-code-sec

## Background

The `django-claude` branch added four features on top of the common ancestor commit
`7c1b242` (Updating the Dockerfile). The `claude-code-sec` branch diverged from the
same point and independently implemented multi-project-root support. This document
describes the plan for porting the three remaining features into `claude-code-sec`,
and provides a structured test checklist covering regressions and implementation
failures.

---

## Branch Topology

```
7c1b242  Updating the Dockerfile  ← common ancestor
│
├── django-claude:
│   ef6eaf8  multi proj-root feature            [ALREADY on sec branch as 0cc6081]
│   f3e02a2  Playwright MCP integration          [TO PORT]
│   2f1ed8c  --api flag                          [TO PORT]
│   81d719d  --prompt-file parameter             [TO PORT]
│
└── claude-code-sec:
    a66e83e  security container prototype
    c64ce4b  tool prompting + VPN
    0cc6081  multi project-root feature
```

---

## Features to Port

### Feature A — Playwright MCP integration (`f3e02a2`)

Enables browser automation via the Model Context Protocol by connecting to a
Chrome instance running with remote debugging on the host.

**Files added (copy verbatim):**
- `mcp-config-template.json` — MCP server config pointing to `localhost:9222`
- `start-chrome-debug.sh` — helper to launch Chrome with remote debugging

**Files created:**
- `.gitignore` — covers Playwright runtime artefacts (`.mcp.json`, `.mcp.json.backup`,
  `.playwright-mcp/`) plus general housekeeping

**Files modified:**
- `compose.yml` — add `PLAYWRIGHT_ENABLED=${PLAYWRIGHT_ENABLED:-0}` env var
- `compose.security.yml` — same env var addition
- `claude-up.sh` — add `--playwright` flag with MCP config generation and host-
  networking compose override (see critical adaptation note below)

**Critical adaptation — compose file path:**
The `django-claude` implementation hardcodes `compose.yml` when switching to host
networking for Playwright. On `claude-code-sec` the active compose file can be either
`compose.yml` (default) or `compose.security.yml` (when `--security` is passed).
The ported code must apply the network switch to whichever file is already selected,
not always to `compose.yml`. Implementation uses `$(dirname "$0")/$COMPOSE_FILE`
rather than a hardcoded filename, and resolves all compose paths to absolute paths
via `$(dirname "$0")/...` for consistency.

---

### Feature B — `--api` flag (`2f1ed8c`)

Loads an Anthropic API key from `~/.anthropic_api_key` (or `$ANTHROPIC_API_KEY`)
and injects it into the container via `-e`. Without this flag the key never enters
the container and sessions use OAuth/Pro quota as normal.

**Files modified:** `claude-up.sh` only.

**Adaptation note:** The `django-claude` final `exec` commands hardcode the service
name `claude`. The `claude-code-sec` version must keep `$SERVICE_NAME` (which is
`claude` in normal mode and `claude-sec` in `--security` mode). The `EXTRA_ARGS`
array that carries `-e ANTHROPIC_API_KEY=...` must be threaded through all exec
paths.

---

### Feature C — `--prompt-file` parameter (`81d719d`)

Enables non-interactive pipeline use. Reads a prompt from a file on the host,
mounts it read-only into the container, and passes it to Claude via `-p`. The
session exits after the prompt completes.

**Files modified:** `claude-up.sh` only.

**Adaptation notes:**
1. The `--prompt-file VALUE` (space-separated) form requires a `while` loop with
   index tracking for flag parsing — the current `for` loop on `claude-code-sec`
   cannot peek at the next argument. The `--name VALUE` handling is upgraded to the
   same while-loop at the same time.
2. The non-interactive exec path must use `$SERVICE_NAME`, not a hardcoded `claude`,
   so that `--prompt-file` works correctly when combined with `--security`.
3. In non-interactive mode the Claude binary is invoked directly (overriding the
   container `CMD`), which means `security-claude-wrapper.sh` is bypassed. This is
   intentional for pipeline use — the wrapper's VPN auto-connect and context-loading
   are interactive conveniences, not pipeline requirements.

---

## Implementation Steps

1. Copy `mcp-config-template.json` and `start-chrome-debug.sh` from `django-claude`.
2. Create `.gitignore` from the `django-claude` version.
3. Add `PLAYWRIGHT_ENABLED=${PLAYWRIGHT_ENABLED:-0}` to `compose.yml` environment block.
4. Add `PLAYWRIGHT_ENABLED=${PLAYWRIGHT_ENABLED:-0}` to `compose.security.yml` environment block.
5. Rewrite `claude-up.sh` — using `claude-code-sec` version as base, integrate:
   a. Convert flag parser to `while` loop supporting `--name VALUE`,
      `--prompt-file VALUE`, and `--prompt-file=VALUE` forms.
   b. Add `PLAYWRIGHT=0`, `USE_API_KEY=0` to boolean-flag scan.
   c. Add API key loading block.
   d. Add `PROMPT_FILE` validation block.
   e. Add Playwright MCP config block, adapted to use the already-selected
      `$COMPOSE_FILE` for network switching.
   f. Add `EXTRA_ARGS` array; thread through all `exec` lines.
   g. Add non-interactive/interactive exec split; all exec paths use `$SERVICE_NAME`.
6. Update `README.md` to document the three new flags.

---

## Test Plan

### Prerequisites

```bash
# Build the security image before running any tests
./build-security.sh
# Optionally build the minimal image
./build-security.sh --minimal
```

---

### 1. Regression Tests — Existing Security Features

These verify that porting the new features has not broken anything that already
worked on `claude-code-sec`.

#### 1.1 Basic interactive launch (no flags)

```bash
./claude-up.sh
```

Expected:
- Mounts `$PWD` as `/app`
- Opens interactive Claude session
- Container name defaults to `claude-code`
- Uses `compose.yml` and service `claude`

---

#### 1.2 Security mode (`--security`)

```bash
./claude-up.sh --security
```

Expected:
- Prints `Security mode enabled`
- Creates `./security-results/` and `./wordlists/` directories
- Uses `compose.security.yml` and service `claude-sec`
- Container name defaults to `claude-code-sec`
- Security tools (nmap, gobuster, subfinder, etc.) are available inside

---

#### 1.3 Multi-project mounting

```bash
./claude-up.sh /tmp/proj1 /tmp/proj2 /tmp/proj3
```

Expected:
- `/tmp/proj1` → `/app`, `/tmp/proj2` → `/app_2`, `/tmp/proj3` → `/app_3`
- `PROJECT_ROOT`, `PROJECT_ROOT_2`, `PROJECT_ROOT_3` set correctly

---

#### 1.4 Multi-project with security mode

```bash
./claude-up.sh /tmp/proj1 /tmp/proj2 --security
```

Expected:
- Both project mounts active
- Security mode active (`compose.security.yml`, service `claude-sec`)

---

#### 1.5 Named container

```bash
./claude-up.sh --name=myaudit
./claude-up.sh --name myaudit   # space form
```

Expected:
- Container named `myaudit`
- Settings persisted at `~/.claude-settings-myaudit`

---

#### 1.6 Root mode

```bash
./claude-up.sh --root
```

Expected:
- `LOCAL_UID=0`, `LOCAL_GID=0` passed to compose

---

#### 1.7 YOLO mode

```bash
./claude-up.sh --yolo
```

Expected:
- Prints `YOLO: passing --dangerously-skip-permissions to claude CLI`
- `claude --dangerously-skip-permissions` invoked inside container

---

#### 1.8 YOLO + security mode combined

```bash
./claude-up.sh --security --yolo
```

Expected:
- Security mode active, YOLO flag passed through

---

### 2. New Feature Tests — Playwright MCP

#### 2.1 Flag recognised without Chrome running

```bash
./claude-up.sh --playwright
```

Expected:
- Prints `Playwright MCP enabled - connecting to host Chrome on localhost:9222`
- `.mcp.json` created in `$PROJECT_ROOT`
- A backup is made if `.mcp.json` already existed
- Compose switches to host networking (verify via `docker inspect` after launch)
- `PLAYWRIGHT_ENABLED=1` visible in container env (`printenv PLAYWRIGHT_ENABLED`)

Failure modes to check:
- `mcp-config-template.json` missing → script should fail with a clear error from `cp`
- `$PROJECT_ROOT/.mcp.json` is a directory instead of a file → `cp` will fail; should not silently corrupt

---

#### 2.2 Playwright + security mode (`--playwright --security`)

```bash
./claude-up.sh --security --playwright
```

Expected:
- Security mode active (service `claude-sec`, security dirs created)
- Network switched to host mode from `compose.security.yml` (not `compose.yml`)
- `.mcp.json` written to project root

Risk: This is the most likely failure point. Verify the temp compose file is derived
from `compose.security.yml` by checking that the security-specific volumes
(`/security/results`, `/security/wordlists`) and capabilities (`NET_RAW`, `NET_ADMIN`)
are still present in the container after launch.

```bash
docker inspect claude-code-sec | grep -A5 '"NetworkMode"'
docker inspect claude-code-sec | grep security
```

---

#### 2.3 `start-chrome-debug.sh` script

On a host with Chrome installed:

```bash
./start-chrome-debug.sh
# Then in another terminal:
curl http://localhost:9222/json/version
```

Expected: Chrome responds with version JSON.

---

#### 2.4 Playwright MCP end-to-end

With Chrome running on port 9222:

```bash
./claude-up.sh --playwright
# Inside container:
claude
# Ask Claude: "Can you use the playwright MCP tool to navigate to example.com and tell me the page title?"
```

Expected: Claude uses the playwright MCP server to control Chrome.

---

### 3. New Feature Tests — `--api` flag

#### 3.1 Key from file

```bash
echo "sk-ant-test-key" > ~/.anthropic_api_key
./claude-up.sh --api
```

Expected:
- Prints `API key loaded — this session will use Anthropic API billing, not Pro quota.`
- Inside container: `printenv ANTHROPIC_API_KEY` returns `sk-ant-test-key`

---

#### 3.2 Key from environment variable

```bash
ANTHROPIC_API_KEY=sk-ant-env-key ./claude-up.sh --api
```

Expected:
- Environment variable takes precedence over file
- Key present inside container

---

#### 3.3 Missing key (error path)

```bash
# Ensure neither file nor env var is set
unset ANTHROPIC_API_KEY
rm -f ~/.anthropic_api_key
./claude-up.sh --api
```

Expected: Error message `--api flag set but no key found...` and non-zero exit.

---

#### 3.4 Without `--api` flag — key must NOT leak

```bash
export ANTHROPIC_API_KEY=sk-ant-should-not-leak
./claude-up.sh
# Inside container:
printenv ANTHROPIC_API_KEY
```

Expected: Variable is absent inside the container. This verifies the security
property that the key never enters the container in normal Pro sessions.

---

#### 3.5 `--api` + `--security` combined

```bash
./claude-up.sh --security --api
```

Expected:
- Security mode active
- API key injected into `claude-sec` service container (not `claude`)

---

### 4. New Feature Tests — `--prompt-file`

#### 4.1 Basic non-interactive run

```bash
echo "What is 2 + 2?" > /tmp/test-prompt.md
./claude-up.sh --prompt-file /tmp/test-prompt.md
```

Expected:
- Prints `Prompt file: /tmp/test-prompt.md (non-interactive mode)`
- Claude answers without an interactive session; container exits
- `--no-session-persistence` is passed (no session saved)

---

#### 4.2 Space-separated form

```bash
./claude-up.sh --prompt-file /tmp/test-prompt.md
```

Expected: identical to `--prompt-file=/tmp/test-prompt.md`.

---

#### 4.3 Non-existent file (error path)

```bash
./claude-up.sh --prompt-file /tmp/does-not-exist.md
```

Expected: Error message `prompt file not found` and non-zero exit before any
Docker invocation.

---

#### 4.4 `--prompt-file` + `--yolo`

```bash
./claude-up.sh --prompt-file /tmp/test-prompt.md --yolo
```

Expected: `--dangerously-skip-permissions` is appended to Claude args.

---

#### 4.5 `--prompt-file` + `--security`

```bash
./claude-up.sh --prompt-file /tmp/test-prompt.md --security
```

Expected:
- Security mode active (service `claude-sec`, security dirs created)
- Non-interactive: Claude runs the prompt and exits
- `security-claude-wrapper.sh` is bypassed (acceptable for pipeline use)

---

#### 4.6 `--prompt-file` + `--api` (pipeline mode)

```bash
./claude-up.sh --prompt-file /tmp/test-prompt.md --api
```

Expected:
- API key injected
- Non-interactive run completes and exits

---

#### 4.7 `MAX_BUDGET_USD` environment variable

```bash
MAX_BUDGET_USD=0.10 ./claude-up.sh --prompt-file /tmp/test-prompt.md --api
```

Expected: `--max-budget-usd 0.10` is passed to the Claude invocation.

---

### 5. Flag Parser Correctness

These quick tests confirm the while-loop flag parser handles edge cases.

```bash
# --name with = form
./claude-up.sh --name=audit-test --security
# Expected: container name "audit-test", settings at ~/.claude-settings-audit-test

# --name with space form
./claude-up.sh --name audit-test --security
# Expected: same as above

# --name missing value (error)
./claude-up.sh --name
# Expected: "Error: --name requires a value" and non-zero exit

# Project paths before flags
./claude-up.sh /tmp/proj1 /tmp/proj2 --security --name=multi
# Expected: two project mounts, security mode, name "multi"

# Too many project paths
./claude-up.sh /tmp/p1 /tmp/p2 /tmp/p3 /tmp/p4 /tmp/p5 /tmp/p6
# Expected: "Error: Maximum 5 project directories supported"

# Non-existent project path
./claude-up.sh /tmp/does-not-exist-dir
# Expected: "Error: Directory does not exist" and non-zero exit
```

---

### 6. Compose File Integrity Checks

After any launch involving Playwright, inspect the temp compose file to confirm
security features survive the `sed` transformation:

```bash
# Launch with both flags, capture the compose run command
bash -x ./claude-up.sh --security --playwright /tmp/proj1 2>&1 | grep "COMPOSE_FILE\|TEMP_COMPOSE\|network_mode"
```

Verify:
- `network_mode: "host"` appears in the temp file
- Security-specific entries (`NET_RAW`, `NET_ADMIN`, `/security/results`, `/security/wordlists`) are preserved
- The temp file is derived from `compose.security.yml`, not `compose.yml`

---

## Risk Summary

| Risk | Severity | Test reference |
|------|----------|---------------|
| Playwright network switch hits `compose.yml` instead of `compose.security.yml` when `--security` is also set | High | §2.2 |
| `$SERVICE_NAME` hardcoded to `claude` in non-interactive exec path | High | §4.5 |
| API key leaking into container without `--api` flag | High | §3.4 |
| `--name VALUE` (space form) broken by while-loop refactor | Medium | §5 |
| Security dirs not created when `--security` + `--prompt-file` combined | Medium | §4.5 |
| Playwright `.mcp.json` silently not created due to missing template file | Medium | §2.1 |
| Base image `ubuntu:latest` in `Dockerfile.security` vs `ubuntu:24.04` in main `Dockerfile` — divergence acceptable but should be a conscious decision | Low | build only |
