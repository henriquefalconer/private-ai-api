# remote-ollama ai-client – Setup Instructions (macOS)

## Installation

Choose one of the following methods:

### Option 1: Quick Install (Recommended)

Run the installer directly via curl:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/henriquefalconer/remote-ollama/master/client/scripts/install.sh)
```

### Option 2: Clone and Install

Clone the repository and run the installer locally:

```bash
git clone https://github.com/henriquefalconer/remote-ollama.git
cd remote-ollama/client
./scripts/install.sh
```

### Option 3: Extended Installation with Claude Code (v2+)

During installation (Step 12), you'll be prompted to optionally install Claude Code integration:

```
Do you want to install Claude Code with Ollama backend support? (default: No)

Benefits:
  - Privacy: All inference on private network
  - No API costs: Free local inference
  - Ralph loop orchestration: Enhanced agent workflows

Limitations:
  - No prompt caching: 2-3x slower on repeated contexts
  - Lower quality models: qwen3-coder, glm-4.7 vs Opus/Sonnet
  - Best for simple tasks: File reads, quick edits, not complex planning

[y/N]:
```

**Default behavior**: If you answer "No" (or press Enter), Claude Code will still use the Anthropic cloud API (recommended). This prompt only configures the **optional** Ollama backend via a shell alias.

**When to opt-in**:
- Privacy-critical projects (all data stays on your network)
- Simple, read-heavy tasks (file exploration, quick edits)
- Learning/experimentation with local models

**When to skip**:
- You plan to use plan mode (requires Opus quality)
- Complex multi-step planning tasks
- Production workflows requiring reliability

For more details, see `client/specs/CLAUDE_CODE.md` lines 171-284.

## What the installer does

The installer will:
- Check/install Homebrew, Python, Tailscale
- Open Tailscale for login and device approval
- Prompt for server hostname (default: `ai-server`)
- Create `~/.ai-client/env` with required environment variables
- Update your shell profile (~/.zshrc) to source the environment
- Install Aider via pipx (v1)
- **[Optional, v2+]** Prompt for Claude Code + Ollama integration (creates `claude-ollama` alias)
- Run a connectivity test

## Post-Installation

### Open a new terminal

```bash
exec $SHELL
```

Or simply open a new terminal window.

### Verify installation

```bash
# Check environment variables
echo $OLLAMA_API_BASE          # http://ai-server:11434 (no /v1 suffix)
echo $OPENAI_API_BASE          # http://ai-server:11434/v1
echo $OPENAI_API_KEY           # ollama

# Check Aider
aider --version

# Test server connectivity (if server is running and you have access)
curl $OLLAMA_API_BASE/v1/models
```

### Verify Claude Code installation (v2+)

If you opted into Claude Code integration:

```bash
# Check Claude Code binary
claude --version

# Check claude-ollama alias exists
grep "claude-ollama" ~/.zshrc     # or ~/.bashrc

# Test Anthropic API endpoint (requires server with Ollama 0.5.0+)
curl $OLLAMA_API_BASE/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: ollama" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"qwen2.5:0.5b","messages":[{"role":"user","content":"hi"}],"max_tokens":1}'

# Run compatibility check
~/.ai-client/check-compatibility.sh
```

**Expected output**:
- `claude --version` shows version 2.1.38 or later
- curl returns JSON with `"content":[{"text":"..."}]`
- Compatibility check shows green "✓ Compatible" message

## Usage

The client has **no persistent service or daemon**. It only configures environment variables.

### v1: Aider (OpenAI-compatible)

#### Run Aider
```bash
aider                     # interactive mode - uses server automatically
aider --yes               # YOLO mode
aider --model ollama/qwen3-coder    # specify model
```

#### Check Configuration
```bash
# Verify environment variables are set
echo $OPENAI_API_BASE    # Should show: http://ai-server:11434/v1
echo $OPENAI_API_KEY     # Should show: ollama

# Test connectivity (requires server access)
curl $OPENAI_API_BASE/models
```

### v2+: Claude Code (Anthropic-compatible)

Claude Code supports two backends:

#### Default: Anthropic Cloud API (Recommended)

Use the standard `claude` command:

```bash
claude --model opus-4-6           # Plan mode (highest quality)
claude --model sonnet-4-5         # Build mode (faster)
claude --model haiku-4-5          # Quick tasks
```

**When to use**:
- ✅ **Always** for plan mode (Opus) - quality critical
- ✅ **Recommended** for build mode (Sonnet) - benefits from prompt caching
- ✅ Complex multi-step planning requiring high-quality reasoning
- ✅ Ralph loops with high parallelism (>20 concurrent subagents)
- ✅ Cache-dependent workloads (>60% cache hit rate)

**Benefits**:
- Full model capabilities (Opus 4.6, Sonnet 4.5, Haiku 4.5)
- Prompt caching support (60-85% hit rate in Ralph loops = 2-3x faster)
- Distributed infrastructure (unlimited parallelism)
- Highest quality output

#### Optional: Local Ollama Backend

If you opted into Claude Code integration during install, use the `claude-ollama` alias:

```bash
claude-ollama --model qwen3-coder       # Local inference via Ollama
claude-ollama --model glm-4.7           # Alternative local model
```

**When to use**:
- ✅ Privacy-critical projects (all data on private network)
- ✅ Simple, read-heavy tasks (file exploration, quick edits)
- ✅ Low cache dependency (<30% cache hit rate)
- ✅ Modest parallelism (<10 concurrent subagents)
- ✅ Learning and experimentation

**When NOT to use**:
- ❌ **Never** for plan mode (Opus) - quality degradation
- ❌ Complex multi-step planning
- ❌ Cache-dependent workloads (Ollama has no caching = 2-3x slower)
- ❌ High parallelism (>50 subagents - single server queuing)
- ❌ Production autonomous agents

#### Ralph Loop Workflows

Standard loop runner:
```bash
./loop.sh 5                           # Run 5 iterations
./loop.sh 10 -g "Implement feature X" # With custom goal
```

With analytics (measure before committing to Ollama):
```bash
# Phase 1: Plan mode baseline with Opus (cloud API)
./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"

# Phase 2: Build mode baseline with Sonnet (cloud API)
./loop-with-analytics.sh build 5 -g "Implement analytics"

# Compare runs to make data-driven decision
./compare-analytics.sh analytics/run-TIMESTAMP-1 analytics/run-TIMESTAMP-2
```

See "Analytics and Performance Measurement" section below for detailed workflow.

#### Quick Reference: Backend Selection

| Scenario | Backend | Command |
|----------|---------|---------|
| **Plan mode** (any complexity) | Anthropic Cloud | `claude --model opus-4-6` |
| **Build mode** (production) | Anthropic Cloud | `claude --model sonnet-4-5` |
| **Build mode** (privacy + simple) | Local Ollama | `claude-ollama --model qwen3-coder` |
| **Quick edits** (any) | Local Ollama or Cloud | Either (test both) |
| **Ralph loops** (complex) | Anthropic Cloud | Use cloud API |
| **Analytics** (measurement) | Start with Cloud | Establish baseline first |

**Rule of thumb**: If unsure, use Anthropic cloud API. Only switch to Ollama after measuring your workload with analytics.

### No Service Management Needed

There's nothing to start, stop, or restart on the client side. Just run tools when you need them.

## Version Management (v2+)

Claude Code updates frequently, and Ollama's Anthropic API is experimental. Breaking changes happen (~30% chance within 12 months). Version management provides a three-layer defense against compatibility issues.

### Quick Start

#### 1. Check Compatibility (Before Updating)

```bash
~/.ai-client/check-compatibility.sh
```

**Exit codes**:
- `0` (green) - Compatible version pair
- `1` (red) - Tool not found or server unreachable
- `2` (yellow) - Known incompatible versions (provides upgrade/downgrade guidance)
- `3` (yellow) - Unknown compatibility (test and update matrix)

#### 2. Pin Versions (Lock to Known-Working State)

```bash
~/.ai-client/pin-versions.sh
```

**What it does**:
- Auto-detects Claude Code version and installation method (npm/brew)
- Queries Ollama server for version
- Pins Claude Code (npm) or displays brew pin command
- Creates `~/.ai-client/.version-lock` file with metadata
- Displays server-side Ollama pinning instructions

**When to use**: Before going to production, after validating a version pair works.

#### 3. Downgrade (Recover from Breaking Update)

```bash
~/.ai-client/downgrade-claude.sh
```

**What it does**:
- Reads `.version-lock` file to find last known-working version
- Detects current Claude Code version
- Prompts for confirmation before downgrading
- Executes downgrade (npm) or displays manual instructions (brew)
- Verifies downgrade success

**When to use**: Immediately after a breaking update, to quickly restore functionality.

### Operational Workflow

**Before updating Claude Code**:
```bash
# Check current compatibility
./check-compatibility.sh

# Update (example with npm)
npm update -g @anthropic-ai/claude-code

# Check new compatibility
./check-compatibility.sh

# Test with Ollama backend
claude-ollama --model qwen3-coder

# If works: update matrix and re-pin
./pin-versions.sh

# If breaks: downgrade immediately
./downgrade-claude.sh
```

**Recommended practice**:
- **Production**: Pin everything, test updates in staging first
- **Development**: More flexibility, but keep `.version-lock` as backup
- **Fallback**: Always maintain Anthropic cloud API access (unaffected by version changes)

For detailed documentation, see `client/specs/VERSION_MANAGEMENT.md`.

## Analytics and Performance Measurement (v2+)

Analytics infrastructure enables **empirical measurement** to validate Ralph loop performance assumptions and make data-driven decisions about Ollama backend viability.

### The Problem

**Prompt rhetoric**: "up to 250-500 parallel Sonnet subagents"

**Empirical reality**: Typical spawn count 5-30 subagents per iteration

**Without measurement**: Cannot predict performance, cannot validate hardware sufficiency, risk over-engineering or under-provisioning.

### Two-Phase Testing Workflow

**Critical**: Always test with Anthropic cloud API first to establish baseline. Do NOT commit to Ollama without empirical validation.

#### Phase 1: Plan Mode Baseline (REQUIRED FIRST STEP)

```bash
./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"
```

**Purpose**: Measure Opus performance during planning phase

**What it measures**:
- Actual subagent spawn patterns (expect 5-15 per iteration, not hundreds)
- Cache hit rate progression (0% → 70-85%)
- Tool usage patterns (Read-heavy reconnaissance)
- Token consumption (high for Opus)

**After Phase 1**: Review `analytics/run-TIMESTAMP/summary.md` and document key metrics.

#### Phase 2: Build Mode Baseline

```bash
./loop-with-analytics.sh build 5 -g "Implement analytics infrastructure"
```

**Purpose**: Measure Sonnet performance during execution phase

**What it measures**:
- Sonnet performance baseline
- Build-specific tool usage (more Edit/Write)
- Cache dependency (expect 60-75% hit rate)
- Iteration count for quality assessment

#### Phase 3: Compare and Decide

```bash
./compare-analytics.sh analytics/run-TIMESTAMP-plan analytics/run-TIMESTAMP-build
```

**Output**: Side-by-side comparison with automatic insight generation and **decision matrix**.

### Decision Matrix

The analytics summary includes a decision matrix that maps your workload characteristics to recommendations:

| Mode | Subagents/iter | Cache hit | Shallow:Deep | Recommendation |
|------|----------------|-----------|--------------|----------------|
| **Plan (Opus)** | Any | >50% | Any | ❌ Keep Anthropic cloud (quality critical) |
| **Build (Sonnet)** | <10 | <30% | >5:1 | ✅ Consider Ollama for simple builds |
| **Build (Sonnet)** | <20 | 30-60% | 3:1-5:1 | ⚠️ Test Ollama carefully |
| **Build (Sonnet)** | <20 | >60% | <3:1 | ❌ Keep Anthropic (cache-dependent) |
| **Build (Sonnet)** | >50 | Any | Any | ❌ Keep Anthropic (parallelism) |

**Key insight**: Plan mode (Opus) should always use Anthropic cloud. Only consider Ollama for build mode (Sonnet) after establishing baseline.

### Key Metrics Explained

**Subagent spawns**: Number of `Task` tool uses per iteration
- **High (>50)**: Requires distributed infrastructure (cloud API)
- **Moderate (10-20)**: Single Ollama server might work
- **Low (<10)**: Good candidate for local inference

**Cache hit rate**: `cache_read_tokens / (cache_creation_tokens + cache_read_tokens)`
- **High (>60%)**: Ollama lacks caching = 2-3x slower
- **Moderate (30-60%)**: Mixed, test carefully
- **Low (<30%)**: Ollama viable (caching less critical)

**Shallow:Deep ratio**: `(Read + Grep + Glob) : (Edit + Write)`
- **High (>5:1)**: Read-heavy, suitable for local models
- **Moderate (3:1-5:1)**: Balanced workload
- **Low (<3:1)**: Write-heavy, requires strong reasoning

### Files Generated

```
analytics/
└── run-2026-02-10-14-30-45/
    ├── summary.md              # Human-readable report with decision matrix
    ├── iteration-1.json        # Full JSON output from iteration 1
    ├── iteration-2.json        # Full JSON output from iteration 2
    └── ...
```

### When to Measure

- ✅ **Before** committing to Ollama backend
- ✅ **After** major Claude Code or Ollama updates
- ✅ When workload characteristics change significantly
- ✅ Before scaling to production (validate assumptions)

### When NOT to Measure

- ❌ For every single task (adds overhead)
- ❌ After establishing stable baseline (unless workload changes)
- ❌ When using cloud API only (measurement not needed)

For detailed documentation, see `client/specs/ANALYTICS.md`.

## Uninstall

If you installed via local clone:
```bash
./scripts/uninstall.sh
```

If you installed via curl-pipe:
```bash
~/.ai-client/uninstall.sh
```

## Troubleshooting

### Critical v0.0.3 Bug: Aider fails with 404 errors

**Symptom**: If you installed v0.0.3 and Aider fails with 404 errors like `http://remote-ollama:11434/v1/api/show not found`.

**Root Cause**: The v0.0.3 `env.template` incorrectly set `OLLAMA_API_BASE` with a `/v1` suffix. This causes Aider/LiteLLM to construct invalid URLs.

**Solution (v0.0.4+)**: Fixed in v0.0.4. To update your v0.0.3 installation:

```bash
# Option 1: Re-run the installer (recommended)
./scripts/install.sh

# Option 2: Manual fix - edit ~/.ai-client/env
nano ~/.ai-client/env
# Change this line:
#   export OLLAMA_API_BASE=http://remote-ollama:11434/v1
# To this (remove /v1):
#   export OLLAMA_API_BASE=http://remote-ollama:11434

# Then reload your environment:
exec $SHELL
```

**Verification**: Check that your environment variables are correct:
```bash
echo $OLLAMA_API_BASE   # Should be http://remote-ollama:11434 (NO /v1)
echo $OPENAI_API_BASE   # Should be http://remote-ollama:11434/v1 (WITH /v1)
```

### "Connection refused" when testing connectivity

**Symptom**: `curl $OPENAI_API_BASE/models` fails with connection refused.

**Solutions**:
- Verify Tailscale is connected: `tailscale status` (should show "Connected")
- Check you can resolve server hostname: `ping remote-ollama` (or your custom hostname)
- Verify you're on the same Tailscale network as the server
- Check Tailscale ACLs: you must have the appropriate tag or device access granted by the admin
- Test if server is responding: ask server admin to verify `./scripts/test.sh` passes
- Verify server hostname in `~/.ai-client/env` matches your Tailscale configuration

### Environment variables not set

**Symptom**: Aider or other tools can't find the API base URL.

**Solutions**:
- Verify env file exists: `cat ~/.ai-client/env` (should show 4 variables)
- Check variables are set in current shell: `echo $OPENAI_API_BASE` (should show URL)
- Ensure you opened a **new terminal** after installation (or run `exec $SHELL`)
- Verify shell profile sources env: `grep ai-client ~/.zshrc` (should show source line with markers)
- Manually source for current session: `source ~/.ai-client/env`
- If using bash instead of zsh, check `~/.bashrc` has the sourcing line

### Aider not found

**Symptom**: `aider` command not found, or `which aider` returns nothing.

**Solutions**:
- Verify pipx is installed: `which pipx` (should return `/opt/homebrew/bin/pipx` or similar)
- Check if Aider is installed: `pipx list` (should show aider-chat)
- Ensure pipx path is in PATH: `echo $PATH | grep .local/bin` (should show `~/.local/bin`)
- Run `pipx ensurepath` to add pipx binaries to PATH, then open new terminal
- Manually check if binary exists: `ls -l ~/.local/bin/aider` (should exist)
- If missing, reinstall: `pipx install aider-chat`

### Aider connects but responses are slow

**Symptom**: Aider works but first request is very slow (30+ seconds).

**Explanation**: This is expected on first request. Large models take time to load into memory.

**Solutions**:
- Ask server admin to run warm-models script: `./scripts/warm-models.sh <model-name>`
- Subsequent requests will be much faster once model is loaded
- Use smaller models for faster initial response (e.g., qwen2.5-coder:7b instead of :32b)

### JSON mode or tools not working

**Symptom**: Aider or tools report JSON mode not supported, or tool calling fails.

**Explanation**: These features are model-dependent. Not all Ollama models support JSON mode or tool calling.

**Solutions**:
- Use a model known to support the feature (check Ollama model documentation)
- For JSON mode: qwen2.5-coder:* and deepseek-r1:* generally support it
- For tool calling: check if the specific model version supports function calling
- The client is working correctly - this is a model capability limitation

### Tailscale not connecting or staying connected

**Symptom**: `tailscale status` shows "Stopped" or connection drops frequently.

**Solutions**:
- Start Tailscale: Open the Tailscale app from Applications
- Verify you're logged in: `tailscale status` should show your email and devices
- Check for network issues: some corporate/public WiFi blocks VPNs
- Try restarting Tailscale: Quit app completely and reopen
- Re-authenticate if needed: `tailscale login` (may require browser)

### Claude Code not found (v2+)

**Symptom**: `claude` command not found, or `which claude` returns nothing.

**Solutions**:
- Verify Claude Code is installed: `claude --version` (should return version 2.1.38+)
- Check installation method:
  - npm: `npm list -g @anthropic-ai/claude-code`
  - brew: `brew list claude-code`
- Ensure npm global bin is in PATH: `echo $PATH | grep npm` (should show npm/bin)
- For npm: Reinstall with `npm install -g @anthropic-ai/claude-code`
- For brew: Reinstall with `brew reinstall claude-code`
- Verify PATH after installation: Open new terminal or run `exec $SHELL`

### claude-ollama fails with authentication error (v2+)

**Symptom**: `claude-ollama` returns "API authentication failed" or similar.

**Solutions**:
- Verify ANTHROPIC_BASE_URL is set in alias: `grep claude-ollama ~/.zshrc`
- Check alias format includes: `ANTHROPIC_AUTH_TOKEN=ollama`, `ANTHROPIC_API_KEY=""`, `ANTHROPIC_BASE_URL=http://...:11434`
- Test Ollama server is reachable: `curl $OLLAMA_API_BASE/v1/messages` (should not 404)
- Verify Ollama version supports Anthropic API: Requires 0.5.0+ (run `check-compatibility.sh`)
- Test with direct curl (see "Verify Claude Code installation" section above)
- If alias is malformed, re-run install.sh Step 12 (Claude Code setup)

### Version compatibility check fails (v2+)

**Symptom**: `check-compatibility.sh` returns yellow warning or red error.

**Scenarios**:

**Exit code 1 (tool not found)**:
- Install missing tool (Claude Code or check Ollama server)
- Verify Tailscale connectivity to server

**Exit code 2 (known incompatible versions)**:
- Follow script's upgrade/downgrade recommendations
- Downgrade Claude Code: `./downgrade-claude.sh` (if .version-lock exists)
- Or upgrade Ollama on server (server admin task)

**Exit code 3 (unknown compatibility)**:
- Test the version pair manually with `claude-ollama --model qwen3-coder`
- If works: Update compatibility matrix in `check-compatibility.sh` and report success
- If breaks: Downgrade Claude Code or upgrade Ollama, then test again

**Downgrade procedure**:
```bash
# Requires existing .version-lock file (created by pin-versions.sh)
./downgrade-claude.sh

# If no lock file exists, manually downgrade to last known-working version
# npm: npm install -g @anthropic-ai/claude-code@2.1.38
# brew: (difficult - consider npm instead)
```

### Ralph loop analytics not capturing data (v2+)

**Symptom**: `loop-with-analytics.sh` completes but `summary.md` is empty or missing metrics.

**Solutions**:
- Verify analytics directory was created: `ls -la analytics/` (should have run-TIMESTAMP dirs)
- Check iteration JSON files exist: `ls analytics/run-*/iteration-*.json`
- Verify JSON files have content: `cat analytics/run-*/iteration-1.json | head`
- Ensure `--output-format=stream-json` is being passed (check loop script)
- Test with simple task first: `./loop-with-analytics.sh build 1 -g "Read IMPLEMENTATION_PLAN.md"`
- Check file permissions: Analytics directory should be writable
- Review script output for errors during JSON parsing

### Ollama backend slower than expected (v2+)

**Symptom**: `claude-ollama` is significantly slower than Anthropic cloud API.

**Explanation**: This is expected due to architectural differences.

**Key factors**:

**1. No prompt caching** (biggest impact):
- Anthropic cloud: 60-85% cache hit rate in Ralph loops = 2-3x speedup
- Ollama: No caching = full context re-processed every request

**Solution**: Use analytics to measure your cache hit rate
```bash
./loop-with-analytics.sh plan 1 -g "your task"
# Check "Overall cache hit rate" in summary.md
# If >60%, keep Anthropic cloud API (Ollama will be much slower)
```

**2. Single server queuing**:
- Anthropic cloud: Unlimited parallelism (distributed infrastructure)
- Ollama: Single server = requests queued

**Solution**: Check subagent spawn count in analytics
```bash
# If "Avg subagents per iteration" > 50, keep cloud API
```

**3. Model quality**:
- Anthropic cloud: Opus 4.6, Sonnet 4.5 (highest quality)
- Ollama: qwen3-coder, glm-4.7 (experimental, lower quality)

**Solution**: For plan mode (Opus), **always** use cloud API

**When Ollama makes sense**:
- Low cache dependency (<30% hit rate)
- Modest parallelism (<10 concurrent subagents)
- Read-heavy workload (>5:1 shallow:deep ratio)
- Privacy-critical projects

**When to keep cloud API**:
- Plan mode (always)
- High cache dependency (>60%)
- High parallelism (>50 subagents)
- Production autonomous agents

### Running the Test Suite

If unsure about the state of your installation, run the comprehensive test suite:

```bash
# Run all 40 tests (v1 + v2+)
./scripts/test.sh

# Run only v1 tests (Aider)
./scripts/test.sh --v1-only

# Run only v2+ tests (Claude Code, version management)
./scripts/test.sh --v2-only

# Skip server connectivity tests (useful if server is down)
./scripts/test.sh --skip-server

# Skip Claude Code tests (if not using v2+)
./scripts/test.sh --skip-claude

# Run only critical tests (environment + dependencies, skip API validation)
./scripts/test.sh --quick

# Show detailed request/response data
./scripts/test.sh --verbose
```

The test suite will identify specific issues with environment configuration, dependencies, server connectivity, Aider integration, Claude Code setup, or version management.

## The client is now fully configured

### v1 (Aider)
All tools respecting the OpenAI API contract will work with zero per-session configuration.

### v2+ (Claude Code)
- **Default**: Claude Code uses Anthropic cloud API (recommended for quality, caching, parallelism)
- **Optional**: Use `claude-ollama` alias for local Ollama backend (privacy, no costs, experimental)
- **Analytics**: Use `loop-with-analytics.sh` to measure performance before committing to Ollama
- **Stability**: Use version management scripts for production deployments

**Decision workflow**:
1. Install client (Aider + optional Claude Code integration)
2. Use Anthropic cloud API by default (`claude --model opus-4-6`)
3. Measure workload with analytics (`loop-with-analytics.sh`)
4. Evaluate against decision matrix (in analytics summary)
5. Only switch to Ollama if metrics support it (<30% cache, <10 subagents, >5:1 shallow:deep)

For detailed v2+ guidance, see:
- `client/specs/CLAUDE_CODE.md` - Backend selection, Ralph loops, alias configuration
- `client/specs/VERSION_MANAGEMENT.md` - Compatibility matrix, pinning, rollback procedures
- `client/specs/ANALYTICS.md` - Two-phase testing, metrics explained, decision criteria
