# remote-ollama ai-client – Setup Instructions (macOS)

## Installation

Choose one of the following methods:

### Option 1: Quick Install (Recommended)

Run the installer directly via curl:

```bash
curl -fsSL https://raw.githubusercontent.com/henriquefalconer/remote-ollama/master/client/scripts/install.sh | bash
```

### Option 2: Clone and Install

Clone the repository and run the installer locally:

```bash
git clone https://github.com/henriquefalconer/remote-ollama.git
cd remote-ollama/client
./scripts/install.sh
```

## What the installer does

The installer will:
- Check/install Homebrew, Python, Tailscale
- Open Tailscale for login and device approval
- Prompt for server hostname (default: `ai-server`)
- Create `~/.ai-client/env` with required environment variables
- Update your shell profile (~/.zshrc) to source the environment
- Install Aider via pipx
- Run a connectivity test

## Post-Installation

### Open a new terminal

```bash
exec $SHELL
```

Or simply open a new terminal window.

### Verify installation

```bash
# Check environment variables
echo $OLLAMA_API_BASE          # http://ai-server:11434/v1
echo $OPENAI_API_BASE          # http://ai-server:11434/v1
echo $OPENAI_API_KEY           # ollama

# Check Aider
aider --version

# Test server connectivity (if server is running and you have access)
curl $OLLAMA_API_BASE/models
```

## Usage

The client has **no persistent service or daemon**. It only configures environment variables.

### Run Aider
```bash
aider                     # interactive mode - uses server automatically
aider --yes               # YOLO mode
```

### Check Configuration
```bash
# Verify environment variables are set
echo $OPENAI_API_BASE    # Should show: http://ai-server:11434/v1
echo $OPENAI_API_KEY     # Should show: ollama

# Test connectivity (requires server access)
curl $OPENAI_API_BASE/models
```

### No Service Management Needed

There's nothing to start, stop, or restart on the client side. Just run tools when you need them.

## Uninstall

If you installed via local clone:
```bash
./scripts/uninstall.sh
```

If you installed via curl-pipe:
```bash
~/.ai-client/uninstall.sh
```

## Troubleshooting

### "Connection refused" when testing connectivity

- Ensure Tailscale is connected and logged in
- Verify you have been granted the appropriate tag in Tailscale ACLs
- Check that the server hostname matches your Tailscale configuration
- Confirm the server is running and accessible

### Environment variables not set

- Ensure you opened a new terminal after installation
- Check that `~/.ai-client/env` exists
- Verify `~/.zshrc` has the sourcing line: `source ~/.ai-client/env`

### Aider not found

- Ensure pipx is installed: `brew install pipx`
- Ensure pipx path is in your PATH
- Try `pipx ensurepath` and open a new terminal

## The client is now fully configured

All tools respecting the OpenAI API contract will work with zero per-session configuration.
