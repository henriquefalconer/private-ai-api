# remote-ollama ai-client Requirements

## macOS

- macOS 14 Sonoma or later
- zsh (default) or bash

## Prerequisites (installer enforces)

- Homebrew
- Python 3.10+ (installed via Homebrew if missing)
- Tailscale (GUI app; installer opens it for login)

## No sudo required

Except for Homebrew/Tailscale installation if chosen by user.

## Shell Profile Modification

The installer will modify your shell profile (`~/.zshrc` for zsh or `~/.bashrc` for bash) to automatically source the environment file (`~/.ai-client/env`). This modification:
- Requires explicit user consent during installation
- Uses marker comments for clean removal by uninstaller
- Ensures environment variables are available in all new shell sessions
