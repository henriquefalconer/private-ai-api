# private-ai-client

macOS client setup for connecting to the private-ai-server.

## Overview

The private-ai-client is a one-time installer that configures your macOS environment to use the private-ai-server's OpenAI-compatible API.

After installation:
- Aider (and other OpenAI-compatible tools) connect automatically
- Zero manual configuration per session
- All API calls go through the secure Tailscale network
- No third-party cloud services involved

## What This Does

1. Installs and configures Tailscale membership
2. Creates environment variables matching the server API contract
3. Installs Aider with automatic server connection
4. Provides clean uninstallation

## Requirements

- macOS 14 Sonoma or later
- Homebrew
- Python 3.10+
- Tailscale account
- Access to a private-ai-server (must be invited to the same Tailscale network)

## Installation

See [SETUP.md](SETUP.md) for complete setup instructions.

Quick start:
```bash
./scripts/install.sh
```

## API Contract

The client relies on the exact API contract documented in [specs/API_CONTRACT.md](specs/API_CONTRACT.md).

The server guarantees:
- OpenAI-compatible `/v1` endpoints
- Hostname resolution via Tailscale
- Support for streaming, JSON mode, tool calling
- No authentication required (network-layer security)

## Usage

After installation, simply run:
```bash
aider                     # interactive mode
aider --yes               # YOLO mode
```

Any tool that supports custom OpenAI base URLs will work automatically.

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
