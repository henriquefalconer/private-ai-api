<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# remote-ollama

A monorepo containing both server and client components for securely accessing your Ollama server remotely from anywhere.

## Project Structure

This monorepo contains two main components:

- **server/** – Ollama server configuration that exposes OpenAI-compatible API endpoints
- **client/** – Client-side setup and configuration for connecting to the remote Ollama server

## Overview

The remote-ollama project provides a complete solution for running Ollama on your own hardware with secure remote access via Tailscale, zero public internet exposure, and zero third-party cloud dependencies.

### Server (ai-server)
- Runs Ollama on a dedicated Apple Silicon Mac with high unified memory
- Exposes OpenAI-compatible `/v1` API endpoints via Ollama
- Accessible only via secure overlay network (Tailscale)
- 24/7 operation for on-demand inference

### Client (ai-client)
- macOS environment setup and configuration
- Connects to the remote Ollama server via Tailscale
- Configures tools like Aider to use your Ollama server automatically
- Zero manual configuration per session

## Quick Start

### Server Setup
See [server/README.md](server/README.md) for detailed server installation and configuration.

### Client Setup
See [client/README.md](client/README.md) for client installation and usage.

## Network Architecture

- **No public internet exposure** – All access via Tailscale private network
- **Device-level authorization** – Tailscale ACLs control access
- **OpenAI-compatible** – Ollama's `/v1` endpoints work with any tool supporting custom OpenAI base URLs

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

- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) – Implementation roadmap
- [AGENTS.md](AGENTS.md) – Agent roles and responsibilities
- [server/SETUP.md](server/SETUP.md) – Server setup instructions
- [client/SETUP.md](client/SETUP.md) – Client setup instructions

## Security Model

- Network-layer isolation via Tailscale
- No built-in authentication (relies on network security)
- No ports exposed to public internet
- Tag-based access control

## License

Proprietary. Copyright (c) 2026 Henrique Falconer. All rights reserved.
