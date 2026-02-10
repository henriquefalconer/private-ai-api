# ai-server Requirements

## macOS

- macOS 14 Sonoma or later
- Apple Silicon (M-series processor) — **required**
- zsh (default) or bash

## Hardware

- High unified memory capacity (≥96 GB strongly recommended for large models)
- 24/7 operation capability with uninterruptible power supply
- High upload bandwidth network connection (≥100 Mb/s recommended for low-latency streaming worldwide)
- Sufficient disk space for model storage (varies by model; 100+ GB recommended)

## Prerequisites (installer enforces)

- Homebrew
- Tailscale (installer installs both GUI app and CLI tools; GUI used for login/setup, CLI used for connection detection)
- Ollama (installed via Homebrew if missing)

## No sudo required for operation

Ollama runs as a user-level LaunchAgent (not root) for security. Sudo may be required only for:
- Initial Homebrew installation (if not already present)
- Initial Tailscale installation (if not already present)

## Network Requirements

- Tailscale account with admin access to configure ACLs
- Ability to tag the server machine in Tailscale (e.g., `tag:ai-server`)
- No public internet exposure required (Tailscale provides secure overlay network)
