# remote-ollama ai-client

macOS client setup for connecting to remote Ollama.

## Overview

The remote-ollama ai-client is a one-time installer that configures your macOS environment to use remote Ollama via OpenAI-compatible API.

After installation:
- Aider (and other OpenAI-compatible tools) connect to remote Ollama automatically
- Zero manual configuration per session
- All API calls go through the secure Tailscale network
- No third-party cloud services involved

## What This Does

1. Installs and configures Tailscale membership
2. Creates environment variables pointing to remote Ollama server
3. Installs Aider with automatic Ollama connection
4. Provides clean uninstallation

## Quick Reference

| Operation | Command | Description |
|-----------|---------|-------------|
| **Start Aider** | `aider` | Launch Aider in interactive mode |
| | `aider --yes` | Launch Aider in YOLO mode (auto-accept changes) |
| **Check config** | `echo $OPENAI_API_BASE` | Display configured API base URL |
| | `echo $OPENAI_API_KEY` | Display configured API key |
| | `cat ~/.ai-client/env` | View all environment variables |
| **Test connectivity** | `curl $OPENAI_API_BASE/models` | Test connection to remote Ollama |
| | `tailscale status` | Check Tailscale connection status |
| **Run tests** | `./scripts/test.sh` | Run comprehensive test suite |
| | `./scripts/test.sh --skip-server` | Run tests without server connectivity checks |
| | `./scripts/test.sh --quick` | Run quick tests (skip model inference) |
| **Reload environment** | `source ~/.ai-client/env` | Reload environment variables in current shell |
| | `exec $SHELL` | Restart shell to apply environment changes |
| **Uninstall** | `./scripts/uninstall.sh` | Remove client configuration and Aider |
| | `~/.ai-client/uninstall.sh` | Uninstall if installed via curl-pipe |

## Requirements

- macOS 14 Sonoma or later
- Homebrew
- Python 3.10+
- Tailscale account
- Access to a remote-ollama ai-server (must be invited to the same Tailscale network)

## Installation

See [SETUP.md](SETUP.md) for complete setup instructions.

Quick start:
```bash
./scripts/install.sh
```

## API Contract

The client relies on the exact API contract documented in [specs/API_CONTRACT.md](specs/API_CONTRACT.md).

The remote Ollama server provides:
- OpenAI-compatible `/v1` endpoints (native Ollama feature)
- Hostname resolution via Tailscale
- Support for streaming, JSON mode, tool calling
- No authentication required (network-layer security)

## Usage

The client has **no persistent daemon or background service**. It only configures environment variables that tools use to connect to remote Ollama.

### Running Aider

After installation, simply run:
```bash
aider                     # interactive mode
aider --yes               # YOLO mode
```

Aider automatically reads the environment variables and connects to remote Ollama.

### Using Other Tools

Any tool that supports custom OpenAI base URLs will work automatically:
```bash
# Environment variables are already set
echo $OPENAI_API_BASE    # http://ai-server:11434/v1
echo $OPENAI_API_KEY     # ollama
```

### No Service Management Required

Unlike the Ollama server, the client requires no start/stop/restart commands. Simply invoke tools when needed.

## Uninstallation

```bash
./scripts/uninstall.sh
```

This removes:
- Aider installation
- Environment variable configuration
- Shell profile modifications

Tailscale and Homebrew are left untouched.

## Documentation

- [SETUP.md](SETUP.md) – Complete setup instructions
- [specs/API_CONTRACT.md](specs/API_CONTRACT.md) – Exact server API interface
- [specs/ARCHITECTURE.md](specs/ARCHITECTURE.md) – Client architecture
- [specs/FUNCTIONALITIES.md](specs/FUNCTIONALITIES.md) – Client functionalities
- [specs/REQUIREMENTS.md](specs/REQUIREMENTS.md) – System requirements
- [specs/SCRIPTS.md](specs/SCRIPTS.md) – Script documentation
- [specs/FILES.md](specs/FILES.md) – Repository layout

## Out of Scope (v1)

- Direct HTTP API calls (use Aider or other tools)
- Linux/Windows support
- IDE plugins
- Custom authentication
