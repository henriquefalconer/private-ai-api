# ai-server Security Model

## Attack Surface Reduction

- No ports exposed to the public internet
- No inbound connections accepted outside the private overlay network
- API has no built-in authentication (relies on network-layer isolation)

## Access Control Layers

1. Tailscale tailnet membership (only invited devices can reach the server IP)
2. Tailscale ACL rules (tag-based or device-based allow-lists for TCP port 11434)

## Revocation & Management

- Revoke access by removing device from tailnet or removing tag from ACL
- Changes propagate near-instantly

## Operational Security Requirements

- Ollama logs remain local to the server machine
- No outbound telemetry or analytics
- Regular security updates for macOS, Tailscale, and Ollama only
- Avoid running the server process as root

## CORS Considerations

- Default Ollama CORS restrictions apply
- Optional: set OLLAMA_ORIGINS environment variable if browser-based clients are planned later
