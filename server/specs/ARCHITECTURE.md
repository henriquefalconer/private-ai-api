# ai-server Architecture

## Core Principles

- Configure Ollama for secure remote access with its native OpenAI-compatible API
- Run Ollama exclusively on a dedicated, always-on machine (separate from clients)
- Zero public internet exposure
- Zero third-party cloud dependencies
- Minimal external dependencies (only Ollama + Tailscale for secure network overlay)
- Native macOS service management via launchd (leveraging Ollama's service model)
- Access restricted to explicitly authorized client devices only

## Intended Deployment Context

- Apple Silicon Mac (M-series) with high unified memory capacity (≥96 GB strongly recommended)
- 24/7 operation with uninterruptible power supply
- High upload bandwidth network connection (≥100 Mb/s recommended for low-latency streaming worldwide)
- The server machine is **not** the development or usage workstation — clients connect remotely

## Server Responsibilities

- Configure Ollama to expose `/v1` OpenAI-compatible API routes (chat/completions, etc.)
- Bind Ollama's API listener to all network interfaces (including private overlay network)
- Let Ollama handle model loading, inference, and unloading automatically
- Leverage Ollama's native support for streaming responses, JSON mode, tool calling (when model supports it)

## Network & Access Model

- Use Tailscale (or equivalent secure overlay VPN) for all remote access to Ollama
- No port forwarding, no dynamic DNS, no public IP binding
- Tailscale ACLs enforce per-device or per-tag authorization
- Ollama's default port (11434) remains accessible only via Tailscale network

## Out of Scope for v1

- Built-in authentication proxy / API keys
- Web-based chat UI
- Automatic model quantization or conversion
- Load balancing across multiple inference nodes
- Monitoring / metrics endpoint
