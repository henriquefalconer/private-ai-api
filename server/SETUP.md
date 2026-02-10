# remote-ollama ai-server – Setup Instructions

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

1. Assign a machine name e.g. "remote-ollama"
2. Create tags e.g. tag:ai-client
3. Add ACL rule example:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ai-client"],
      "dst": ["tag:ai-server:11434"]
    }
  ]
}
```

### 7. Verify server reachability

From an authorized client machine:

```bash
curl http://remote-ollama:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "any-available-model",
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

## Server is now operational

Clients must join the same tailnet and receive the appropriate tag to connect.

## Managing the Ollama Service

The Ollama service runs as a user-level LaunchAgent and starts automatically at login.

### Check Status
```bash
# Check if service is loaded
launchctl list | grep com.ollama

# Test API availability
curl -sf http://localhost:11434/v1/models
```

### Start Service
```bash
# The service starts automatically, but you can manually start it with:
launchctl kickstart gui/$(id -u)/com.ollama
```

### Stop Service
```bash
# Temporarily stop the service (will restart on next login)
launchctl stop gui/$(id -u)/com.ollama
```

### Restart Service
```bash
# Kill and immediately restart the service
launchctl kickstart -k gui/$(id -u)/com.ollama
```

### Disable Service (Prevent Auto-Start)
```bash
# Completely unload the service
launchctl bootout gui/$(id -u)/com.ollama
```

### Re-enable Service
```bash
# Load the service again
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist
```

### View Logs
```bash
# Monitor standard output
tail -f /tmp/ollama.stdout.log

# Monitor errors
tail -f /tmp/ollama.stderr.log
```

### Check Current Models
```bash
# List all pulled models
ollama list

# Pull a new model
ollama pull <model-name>
```

### (Optional) Warm Models for Faster First Response

The `warm-models.sh` script eliminates cold-start latency by pre-loading models into memory. This is particularly useful for large models that take significant time to load on first request.

```bash
# Navigate to server directory if not already there
cd /path/to/remote-ollama/server

# Warm specific models
./scripts/warm-models.sh qwen2.5-coder:32b deepseek-r1:70b
```

The script will:
1. Verify Ollama is running
2. Pull each model (if not already downloaded)
3. Send a minimal inference request to load the model into memory
4. Report success/failure for each model

This step is optional but recommended if you want immediate response times after server boot or restart. You can also integrate this into launchd for automatic warmup at boot - see the script's inline comments for details.
