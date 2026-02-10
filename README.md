<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# remote-ollama

A monorepo containing both server and client components for secure remote access to self-hosted Ollama.

## Project Structure

This monorepo contains two main components:

- **server/** – Ollama server configuration that exposes OpenAI-compatible API endpoints
- **client/** – Client-side setup and configuration for connecting to remote Ollama

## Overview

The remote-ollama project provides a complete solution for running Ollama on your own hardware with secure remote access via Tailscale, zero public internet exposure, and zero third-party cloud dependencies.

### Server (ai-server)
- Runs Ollama on a dedicated Apple Silicon Mac with high unified memory
- Exposes dual API: OpenAI-compatible `/v1` and Anthropic-compatible `/v1/messages` endpoints
- Accessible only via secure overlay network (Tailscale)
- 24/7 operation for on-demand inference
- Supports both Aider (OpenAI API) and Claude Code (Anthropic API)

### Client (ai-client)
- macOS environment setup and configuration
- Connects to remote Ollama server via Tailscale
- Configures tools (Aider, optionally Claude Code) to use remote Ollama automatically
- Optional: Claude Code can use either Anthropic cloud API or remote Ollama backend
- Zero manual configuration per session

## Quick Start

### Server Setup
See [server/README.md](server/README.md) for detailed server installation and configuration.

### Client Setup
See [client/README.md](client/README.md) for client installation and usage.

## Supported Tools in Client

### Aider (v1)
- Uses OpenAI-compatible API (`/v1/chat/completions`)
- Connects to remote Ollama automatically after installation
- Zero configuration per session

### Claude Code (v2+)
- **Default**: Uses Anthropic cloud API (Opus 4.6, Sonnet 4.5)
- **Optional**: Can use local Ollama via Anthropic-compatible API (`/v1/messages`)
- Optional backend switching via shell alias
- Version compatibility checking and management tools included

## Network Architecture

- **No public internet exposure** – All access via Tailscale private network
- **Device-level authorization** – Tailscale ACLs control access
- **Dual API support** – OpenAI-compatible `/v1/*` and Anthropic-compatible `/v1/messages`
- Works with any tool supporting custom OpenAI or Anthropic base URLs

## Requirements

### Server
- Apple Silicon Mac (M-series) with ≥96 GB unified memory recommended
- macOS 14 Sonoma or later
- High upload bandwidth (≥100 Mb/s recommended)
- 24/7 operation capability

### Client
- macOS 14 Sonoma or later
- Homebrew
- Python 3.10+
- Tailscale account

## Documentation

### Setup Guides
- [server/README.md](server/README.md) – Server overview and quick reference
- [server/SETUP.md](server/SETUP.md) – Server installation instructions
- [client/README.md](client/README.md) – Client overview and quick reference
- [client/SETUP.md](client/SETUP.md) – Client installation instructions

### Specifications
- **Client specs**: `client/specs/` – Client architecture, API contract, Claude Code integration, analytics, version management
- **Server specs**: `server/specs/` – Server architecture, dual API support, Anthropic compatibility

### Project Management
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) – Implementation status and roadmap
- [AGENTS.md](AGENTS.md) – Component responsibilities and coordination

## Optional Features (v2+)

### Claude Code with Remote Ollama Backend
- Alternative to Anthropic cloud API for privacy-critical work
- Shell alias for easy backend switching (`claude-ollama`)
- All inference stays on private Tailscale network
- Suitable for simple tasks, file operations, quick edits
- **Not recommended** for complex autonomous workflows (no prompt caching, lower model quality)

### Performance Analytics
- Measure actual tool usage and token consumption
- Compare performance between cloud and local backends
- Make informed decisions about backend suitability
- Tools: `loop-with-analytics.sh`, `compare-analytics.sh`

### Version Management
- Compatibility checking between Claude Code and Ollama versions
- Version pinning for stable production environments
- Quick rollback if updates break compatibility
- Tools: `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh`

## Security Model

- Network-layer isolation via Tailscale
- No built-in authentication (relies on network security)
- No ports exposed to public internet
- Tag-based access control

## License

Proprietary. Copyright (c) 2026 Henrique Falconer. All rights reserved.
