# private-ai-server

OpenAI-compatible LLM inference server for Apple Silicon Macs with high unified memory.

## Overview

The private-ai-server provides a secure, private LLM inference API that:
- Exposes OpenAI-compatible `/v1` endpoints
- Runs exclusively on a dedicated, always-on Mac
- Has zero public internet exposure
- Uses Tailscale for secure remote access
- Requires no third-party cloud dependencies

## Intended Deployment

- **Hardware**: Apple Silicon Mac (M-series) with ≥96 GB unified memory recommended
- **Network**: High upload bandwidth (≥100 Mb/s recommended for worldwide low-latency streaming)
- **Uptime**: 24/7 operation with UPS recommended
- **OS**: macOS 14 Sonoma or later

## Architecture

See [specs/ARCHITECTURE.md](specs/ARCHITECTURE.md) for full architectural details.

Key principles:
- Minimal external dependencies (Ollama + Tailscale)
- Native macOS service management via launchd
- Network-layer security only (no built-in auth)
- Access restricted to authorized Tailscale devices

## API

The server exposes OpenAI-compatible endpoints at:
```
http://<tailscale-assigned-ip>:11434/v1
```

Supported endpoints:
- `/v1/chat/completions` (streaming, JSON mode, tool calling)
- `/v1/models`
- `/v1/responses`

Full API contract is documented in [../client/specs/API_CONTRACT.md](../client/specs/API_CONTRACT.md).

## Setup

See [SETUP.md](SETUP.md) for complete installation instructions.

Quick summary:
1. Install Tailscale and Ollama
2. Configure Ollama to listen on all interfaces via launchd
3. Configure Tailscale ACLs for client access
4. Pull desired models
5. Verify connectivity from client

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
