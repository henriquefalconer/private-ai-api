# private-ai-server – Setup Instructions

Target: Apple Silicon Mac (high memory recommended) running recent macOS

## Prerequisites

- Administrative access
- Homebrew package manager
- Tailscale account (free personal tier sufficient)

## Step-by-Step Setup

### 1. Install Tailscale

```bash
brew install tailscale
open -a Tailscale          # complete login and device approval
```

### 2. Install Ollama (if not already present)

```bash
brew install ollama
```

### 3. Configure Ollama to listen on all interfaces

Create user-level launch agent:

```bash
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.ollama.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0</string>
    </dict>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ollama.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ollama.stderr.log</string>
</dict>
</plist>
EOF

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist
```

### 4. Restart Ollama service (if needed)

```bash
launchctl kickstart -k gui/$(id -u)/com.ollama
```

### 5. (Optional) Pre-pull large models for testing

```bash
ollama pull <model-name>   # repeat for desired models
```

### 6. Configure Tailscale ACLs

In Tailscale admin console at tailscale.com:

1. Assign a machine name e.g. "private-ai-server"
2. Create tags e.g. tag:ai-client
3. Add ACL rule example:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ai-client"],
      "dst": ["tag:private-ai-server:11434"]
    }
  ]
}
```

### 7. Verify server reachability

From an authorized client machine:

```bash
curl http://private-ai-server:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "any-available-model",
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

## Server is now operational

Clients must join the same tailnet and receive the appropriate tag to connect.
