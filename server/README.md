# ai-server

Ollama server configuration for secure remote access from Apple Silicon Macs with high unified memory.

## Overview

The ai-server configures Ollama to provide secure, remote LLM inference that:
- Exposes Ollama's native OpenAI-compatible `/v1` endpoints
- Runs exclusively on a dedicated, always-on Mac
- Has zero public internet exposure
- Uses Tailscale for secure remote access
- Requires no third-party cloud dependencies beyond Ollama and Tailscale

## Quick Reference

| Operation | Command | Description |
|-----------|---------|-------------|
| **Check status** | `launchctl list \| grep com.ollama` | Check if Ollama service is loaded |
| | `curl -sf http://localhost:11434/v1/models` | Test API endpoint availability |
| **Start service** | `launchctl kickstart gui/$(id -u)/com.ollama` | Start the service if stopped |
| **Stop service** | `launchctl stop gui/$(id -u)/com.ollama` | Stop the service temporarily |
| **Restart service** | `launchctl kickstart -k gui/$(id -u)/com.ollama` | Kill and restart the service immediately |
| **View logs** | `tail -f /tmp/ollama.stdout.log` | Monitor standard output logs |
| | `tail -f /tmp/ollama.stderr.log` | Monitor error logs |
| **Check models** | `ollama list` | List all pulled models |
| **Warm models** | `./scripts/warm-models.sh <model-name>` | Pre-load models into memory for faster response |
| **Run tests** | `./scripts/test.sh` | Run comprehensive test suite |
| | `./scripts/test.sh --skip-model-tests` | Run tests without model inference |
| **Uninstall** | `./scripts/uninstall.sh` | Remove server configuration and service |

## Intended Deployment

- **Hardware**: Apple Silicon Mac (M-series) with ≥96 GB unified memory recommended
- **Network**: High upload bandwidth (≥100 Mb/s recommended for worldwide low-latency streaming)
- **Uptime**: 24/7 operation with UPS recommended
- **OS**: macOS 14 Sonoma or later

## Architecture

See [specs/ARCHITECTURE.md](specs/ARCHITECTURE.md) for full architectural details.

Key principles:
- Built on Ollama's native capabilities
- Minimal external dependencies (only Ollama + Tailscale)
- Native macOS service management via launchd
- Network-layer security only (no built-in auth)
- Access restricted to authorized Tailscale devices

## API

Ollama exposes OpenAI-compatible endpoints at:
```
http://<tailscale-assigned-ip>:11434/v1
```

Supported Ollama endpoints:
- `/v1/chat/completions` (streaming, JSON mode, tool calling)
- `/v1/models`
- `/v1/responses`

Full API contract is documented in [../client/specs/API_CONTRACT.md](../client/specs/API_CONTRACT.md).

## Setup

See [SETUP.md](SETUP.md) for complete installation instructions.

Quick summary:
1. Install Tailscale and Ollama
2. Configure Ollama to listen on all interfaces via launchd (enables remote access)
3. Configure Tailscale ACLs for client access
4. Pull desired models via Ollama CLI
5. Verify connectivity from client

## Operations

Once installed, the Ollama service runs as a LaunchAgent and starts automatically at login.

### Check Status
```bash
# Check if Ollama service is running
launchctl list | grep com.ollama

# Test API endpoint
curl -sf http://localhost:11434/v1/models
```

### Start Service
```bash
# Start the service (if stopped)
launchctl kickstart gui/$(id -u)/com.ollama
```

### Stop Service
```bash
# Stop the service temporarily
launchctl stop gui/$(id -u)/com.ollama
```

### Restart Service
```bash
# Restart the service (kill and restart immediately)
launchctl kickstart -k gui/$(id -u)/com.ollama
```

### Disable Service (Prevent Auto-Start)
```bash
# Unload the service completely
launchctl bootout gui/$(id -u)/com.ollama
```

### Re-enable Service
```bash
# Load the service again
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist
```

### View Logs
```bash
# Standard output
tail -f /tmp/ollama.stdout.log

# Error output
tail -f /tmp/ollama.stderr.log
```

### Warm Models (Optional Performance Optimization)

The `warm-models.sh` script pre-loads models into memory for faster first-request latency. This is useful for ensuring models are immediately ready after server boot or restart.

```bash
# Warm a single model
./scripts/warm-models.sh qwen2.5-coder:32b

# Warm multiple models
./scripts/warm-models.sh qwen2.5-coder:32b deepseek-r1:70b llama3.2-vision:90b
```

What it does:
- Pulls each model (downloads if not already present)
- Sends a minimal inference request to force-load the model into memory
- Continues processing remaining models if one fails
- Provides detailed progress reporting and summary

When to use it:
- After server restarts or reboots to eliminate cold-start latency
- Before critical workloads that require immediate response
- Can be integrated into launchd for automatic warmup at boot (see script comments)

## Security

See [specs/SECURITY.md](specs/SECURITY.md) for the complete security model.

- No public internet exposure
- Tailscale-only access
- Tag-based or device-based ACLs
- No built-in authentication (network-layer isolation)

## Documentation

- [SETUP.md](SETUP.md) – Complete setup instructions
- [specs/ARCHITECTURE.md](specs/ARCHITECTURE.md) – Architecture and principles
- [specs/FUNCTIONALITIES.md](specs/FUNCTIONALITIES.md) – Detailed functionality specifications
- [specs/SECURITY.md](specs/SECURITY.md) – Security model and requirements
- [specs/INTERFACES.md](specs/INTERFACES.md) – External interfaces
- [specs/FILES.md](specs/FILES.md) – Repository layout

## Out of Scope (v1)

- Built-in authentication proxy / API keys
- Web-based chat UI
- Automatic model quantization
- Load balancing across multiple nodes
- Monitoring / metrics endpoint
