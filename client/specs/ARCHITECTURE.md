# ai-client Architecture

## Responsibilities of ai-client

- Install and configure Tailscale membership
- Create and source environment variables that exactly match the ai-server API contract (see API_CONTRACT.md)
- Install Aider (the only supported interface in v1) in a way that automatically reads the above variables
- Provide clean uninstallation
- Document the API contract so future interfaces can be added without changing the installer

## Responsibilities of ai-server (from client perspective)

- Guarantee the exact HTTP contract in API_CONTRACT.md
- Resolve the hostname `ai-server` via Tailscale
- Accept connections only from authorized Tailscale tags

## Client Runtime

- No daemon, no wrapper binary, no persistent process
- Only environment configuration + Aider installation
- All API calls are performed by the user-chosen interface (Aider)

## Out of Scope (v1)

- Any code that makes direct HTTP calls
- Linux/Windows installers
- IDE plugins
- Custom auth beyond Tailscale + dummy API key
