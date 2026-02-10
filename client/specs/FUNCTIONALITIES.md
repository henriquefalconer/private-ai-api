# ai-client Functionalities (v1)

## Core Functionality

- One-time installer that makes the remote Ollama server immediately usable by OpenAI-compatible tools
- Sets all required environment variables pointing to the remote Ollama server (see API_CONTRACT.md)
- Modifies shell profile (`~/.zshrc` or `~/.bashrc`) to source environment file automatically (with user consent)
- Installs Aider and ensures it connects to the remote Ollama server automatically
- Uninstaller that removes only client-side changes
- Comprehensive test script for automated validation of all client functionality

## After Installation

- User can run `aider` or `aider --yes` and it will connect to the remote Ollama server
- Any other tool that honors `OPENAI_API_BASE` + `OPENAI_API_KEY` will work without extra flags
- **No persistent daemon or service** – the client is purely environment configuration
- No start/stop/restart commands needed – simply invoke tools when needed

## Client Responsibilities

- Guarantee that after `./scripts/install.sh`, the environment matches API_CONTRACT.md exactly
- Verify connectivity to the remote Ollama server (optional test curl in installer)
- Provide clear error messages if Tailscale is not joined or tag is missing
