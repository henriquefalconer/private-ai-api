# ai-server External Interfaces

## Primary Interface

- HTTP API at `http://<tailscale-assigned-ip>:11434/v1`
- Fully OpenAI-compatible schema (chat completions endpoint)
- No custom routes or extensions in v1

## Configuration Interface

- Environment variables (primarily OLLAMA_HOST)
- launchd plist for service persistence

## Service Management Interface

The Ollama service runs as a user-level LaunchAgent and is managed via launchctl:

- **Check status**: `launchctl list | grep com.ollama`
- **Start**: `launchctl kickstart gui/$(id -u)/com.ollama`
- **Stop**: `launchctl stop gui/$(id -u)/com.ollama`
- **Restart**: `launchctl kickstart -k gui/$(id -u)/com.ollama`
- **Disable**: `launchctl bootout gui/$(id -u)/com.ollama`
- **Re-enable**: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist`
- **View logs**: `tail -f /tmp/ollama.stdout.log` or `/tmp/ollama.stderr.log`

## Management Interface (minimal)

- Tailscale admin console (external to this monorepo) for ACLs and device approval
- Optional boot script for model pre-warming

## Intended Client Consumption Patterns (informative only)

- CLI tools that support custom OpenAI base URL
- Code editors / IDE extensions with OpenAI-compatible provider settings
- Custom scripts using HTTP requests or OpenAI SDKs with base_url override
