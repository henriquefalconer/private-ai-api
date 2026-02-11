#!/bin/bash
set -euo pipefail

# remote-ollama-proxy ai-server install script
# Automates the setup of Ollama + Tailscale for private LLM inference
# Source: server/specs/* and server/SETUP.md

# Suppress Homebrew noise
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

fatal() {
    error "$1"
    exit 1
}

section_break() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

important_section() {
    echo ""
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║  $(printf "%-60s" "$1")  ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Banner
echo "================================================"
echo "  remote-ollama-proxy ai-server Installation"
echo "================================================"
echo ""

# Step 1: Detect macOS + Apple Silicon
info "Checking system requirements..."
if [[ "$(uname)" != "Darwin" ]]; then
    fatal "This script requires macOS. Detected: $(uname)"
fi

MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 14 ]]; then
    fatal "This script requires macOS 14 (Sonoma) or later. Detected: $MACOS_VERSION"
fi

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
    fatal "This script requires Apple Silicon (arm64). Detected: $ARCH"
fi

# Validate shell (zsh or bash)
USER_SHELL=$(basename "$SHELL")
if [[ "$USER_SHELL" != "zsh" && "$USER_SHELL" != "bash" ]]; then
    fatal "This script requires zsh or bash shell. Detected: $USER_SHELL"
fi

info "✓ macOS $MACOS_VERSION with Apple Silicon detected"
info "✓ Shell: $USER_SHELL"

# Step 2: Check for Homebrew
info "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    warn "Homebrew not found"
    echo "Please install Homebrew from https://brew.sh and re-run this script"
    fatal "Homebrew is required"
fi
info "✓ Homebrew found: $(brew --version | head -n1)"

# Step 3: Check/install Tailscale
info "Checking for Tailscale..."

# Check if GUI app exists
if ! [ -d "/Applications/Tailscale.app" ]; then
    echo ""
    warn "Tailscale installation will request your password (sudo access required)"
    echo "This is normal - Homebrew needs permission to install the system extension."
    echo ""
    info "Installing Tailscale GUI via Homebrew (this may take a minute)..."
    brew install --cask tailscale > /tmp/tailscale-install.log 2>&1 || fatal "Failed to install Tailscale GUI"
    info "✓ Tailscale GUI installed"
else
    info "✓ Tailscale GUI already installed"
fi

# Check if CLI tools are available
if ! command -v tailscale &> /dev/null; then
    info "Installing Tailscale CLI tools..."
    brew install tailscale > /tmp/tailscale-cli-install.log 2>&1 || fatal "Failed to install Tailscale CLI"
    info "✓ Tailscale CLI installed"
else
    info "✓ Tailscale CLI already installed"
fi

# Check if already connected
TAILSCALE_IP=""
if command -v tailscale &> /dev/null; then
    if tailscale status &> /dev/null 2>&1; then
        # Check if we have an IP
        POTENTIAL_IP=$(tailscale ip -4 2>/dev/null | head -n1)
        if [[ -n "$POTENTIAL_IP" ]]; then
            TAILSCALE_IP="$POTENTIAL_IP"
            info "✓ Tailscale already connected! IP: $TAILSCALE_IP"
        fi
    fi
fi

# If not connected, start connection flow
if [[ -z "$TAILSCALE_IP" ]]; then
    echo ""
    echo "================================================"
    echo "  Tailscale Connection Required"
    echo "================================================"
    echo ""

    # Try GUI first
    if [ -d "/Applications/Tailscale.app" ]; then
        info "Opening Tailscale GUI..."
        open -a Tailscale 2>/dev/null && info "✓ Tailscale GUI opened" || warn "Failed to open GUI"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  First-time Tailscale Setup Instructions"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Complete these steps (first-time setup may take a few minutes):"
        echo ""
        echo "  1. macOS will prompt you for several permissions:"
        echo "     → System Extension: Click 'Allow' (required for VPN)"
        echo "     → Notifications: Click 'Allow' (recommended for connection status)"
        echo "     → Start on log in: Click 'Yes, start on log in' (recommended)"
        echo "       This ensures Tailscale reconnects automatically after reboot"
        echo ""
        echo "  2. You may need to activate the VPN configuration"
        echo "     → If Tailscale doesn't connect automatically, open:"
        echo "       System Settings > VPN > Tailscale"
        echo "     → Toggle the switch to activate it"
        echo ""
        echo "  3. In the Tailscale app or browser window:"
        echo "     → Click 'Log in' or 'Sign up' to create/access your account"
        echo "     → Follow the browser authentication flow"
        echo "     → If creating a new account, you'll see a survey form"
        echo "       (Fill it out or skip - it's optional for getting started)"
        echo "     → You may see an introduction/tutorial - you can skip it"
        echo "       (Look for 'Skip this introduction' to speed up setup)"
        echo "     → Approve the device in your Tailscale admin (if prompted)"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    elif command -v tailscale &> /dev/null; then
        # Fall back to CLI
        info "Starting Tailscale CLI authentication..."
        echo ""
        echo "Running: tailscale up"
        echo "Please follow the URL that appears to authenticate."
        echo ""
        tailscale up || warn "Tailscale up returned an error, but you may still be able to authenticate"
        echo ""
    else
        fatal "Neither Tailscale GUI nor CLI is available. Installation may have failed."
    fi

    # Wait with interactive prompt (no timeout)
    info "Waiting for Tailscale connection..."
    echo "Press Enter after completing the steps above to check connection status"
    echo ""

    CONNECTED=false

    while [[ "$CONNECTED" == "false" ]]; do
        # Wait for user to press Enter
        read -r -p "Press Enter to check connection status (or Ctrl+C to exit and run script later)... " < /dev/tty

        # Check status
        echo "Checking Tailscale status..."
        if command -v tailscale &> /dev/null && tailscale status &> /dev/null 2>&1; then
            POTENTIAL_IP=$(tailscale ip -4 2>/dev/null | head -n1)
            if [[ -n "$POTENTIAL_IP" ]]; then
                TAILSCALE_IP="$POTENTIAL_IP"
                CONNECTED=true
                echo ""
                info "✓ Tailscale connected! IP: $TAILSCALE_IP"
                echo ""
                break
            else
                warn "Tailscale is running but not yet connected"
                echo "Tips:"
                echo "  • Make sure you completed the authentication in your browser"
                echo "  • Check if VPN is activated in System Settings > VPN"
                echo "  • Try opening the Tailscale app to see its status"
                echo ""
            fi
        else
            warn "Tailscale is not responding"
            echo "Tips:"
            echo "  • Make sure you allowed the System Extension"
            echo "  • Check System Settings > Privacy & Security for pending permissions"
            echo "  • Try opening the Tailscale app manually"
            echo "  • You can also exit (Ctrl+C) and re-run this script after setup"
            echo ""
        fi
    done
fi

# Step 4: Check/install Ollama
info "Checking for Ollama..."
if ! command -v ollama &> /dev/null; then
    info "Installing Ollama via Homebrew (this may take a minute)..."
    brew install ollama > /tmp/ollama-install.log 2>&1 || fatal "Failed to install Ollama"
fi
OLLAMA_VERSION=$(ollama --version 2>/dev/null | head -n1 || echo 'version unknown')
info "✓ Ollama installed: $OLLAMA_VERSION"

# Step 5: Validate Ollama binary path
info "Validating Ollama binary path..."
OLLAMA_PATH=""
if [[ -x "/opt/homebrew/bin/ollama" ]]; then
    OLLAMA_PATH="/opt/homebrew/bin/ollama"
elif command -v ollama &> /dev/null; then
    OLLAMA_PATH="$(which ollama)"
else
    fatal "Could not locate ollama binary"
fi
info "✓ Ollama binary: $OLLAMA_PATH"

# Step 6: Stop any existing Ollama services
info "Stopping any existing Ollama services..."
# Try to stop brew services version
if brew services list | grep -q ollama; then
    brew services stop ollama 2>/dev/null || true
fi

# Try to bootout existing launchd agent
LAUNCHD_DOMAIN="gui/$(id -u)"
LAUNCHD_LABEL="com.ollama"
launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" 2>/dev/null || true
sleep 2
info "✓ Existing services stopped"

# Step 7: Create LaunchAgent plist
PLIST_PATH="$HOME/Library/LaunchAgents/com.ollama.plist"
info "Creating LaunchAgent plist at $PLIST_PATH..."
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>$OLLAMA_PATH</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>127.0.0.1</string>
        <!-- Optional CORS configuration (uncomment if needed):
        <key>OLLAMA_ORIGINS</key>
        <string>*</string>
        -->
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

info "✓ LaunchAgent plist created"

# Step 8: Load the LaunchAgent
info "Loading Ollama LaunchAgent..."
launchctl bootstrap "$LAUNCHD_DOMAIN" "$PLIST_PATH" || fatal "Failed to load LaunchAgent"
sleep 3
info "✓ LaunchAgent loaded"

# Step 9: Verify Ollama is running
info "Verifying Ollama is listening on port 11434..."
RETRY_COUNT=0
MAX_RETRIES=15
OLLAMA_READY=false

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
    if curl -sf http://localhost:11434/v1/models &> /dev/null; then
        OLLAMA_READY=true
        break
    fi
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [[ "$OLLAMA_READY" == "true" ]]; then
    info "✓ Ollama is responding on port 11434"
else
    fatal "Ollama did not respond after 30 seconds. Check logs: /tmp/ollama.stderr.log"
fi

# Step 10: Verify process ownership (must not be root)
info "Verifying Ollama is running as user (not root)..."
OLLAMA_PID=$(pgrep -f "ollama serve" | head -n1)
if [[ -n "$OLLAMA_PID" ]]; then
    OLLAMA_USER=$(ps -o user= -p "$OLLAMA_PID")
    if [[ "$OLLAMA_USER" == "root" ]]; then
        fatal "Security violation: Ollama is running as root. This is not allowed."
    fi
    info "✓ Ollama running as user: $OLLAMA_USER (PID: $OLLAMA_PID)"
else
    warn "Could not verify Ollama process ownership"
fi

# Step 11: Self-test API endpoint
info "Running self-test on API endpoint..."
TEST_RESPONSE=$(curl -sf http://localhost:11434/v1/models 2>/dev/null || echo "FAILED")
if [[ "$TEST_RESPONSE" == "FAILED" ]] || ! echo "$TEST_RESPONSE" | grep -q "object"; then
    fatal "Self-test failed: /v1/models did not return valid JSON"
fi
info "✓ Self-test passed: /v1/models returned valid response"

# Step 12: HAProxy Installation (Optional - Defense in Depth)
section_break
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║                HAProxy Proxy Layer (Optional)                 ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "HAProxy provides defense-in-depth security for your Ollama server:"
echo ""
echo "  ${GREEN}Benefits:${NC}"
echo "    • Endpoint allowlisting - Only specific API paths are accessible"
echo "    • Single choke point - All network access funnels through one boundary"
echo "    • Defense in depth - Three security layers (Tailscale + HAProxy + loopback)"
echo "    • Future-expandable - Can add rate limits, auth, logging later"
echo ""
echo "  ${YELLOW}Tradeoffs:${NC}"
echo "    • Adds one more service to manage"
echo "    • Minimal latency overhead (~1ms per request)"
echo ""
echo "Without HAProxy, Ollama will bind to all interfaces (less secure but functional)."
echo ""

# User consent prompt with default Yes
INSTALL_HAPROXY="Y"
read -r -p "Install HAProxy proxy? (Y/n): " HAPROXY_CHOICE < /dev/tty || HAPROXY_CHOICE="Y"
if [[ -z "$HAPROXY_CHOICE" ]]; then
    HAPROXY_CHOICE="Y"
fi

# Normalize to uppercase
HAPROXY_CHOICE=$(echo "$HAPROXY_CHOICE" | tr '[:lower:]' '[:upper:]')

if [[ "$HAPROXY_CHOICE" == "Y" || "$HAPROXY_CHOICE" == "YES" ]]; then
    info "Installing HAProxy..."

    # Check if HAProxy is already installed
    if ! command -v haproxy &> /dev/null; then
        info "Installing HAProxy via Homebrew..."
        brew install haproxy > /tmp/haproxy-install.log 2>&1 || fatal "Failed to install HAProxy"
        info "✓ HAProxy installed"
    else
        HAPROXY_VERSION=$(haproxy -v 2>&1 | head -n1 || echo 'version unknown')
        info "✓ HAProxy already installed: $HAPROXY_VERSION"
    fi

    # Validate HAProxy binary path
    HAPROXY_PATH=""
    if [[ -x "/opt/homebrew/bin/haproxy" ]]; then
        HAPROXY_PATH="/opt/homebrew/bin/haproxy"
    elif command -v haproxy &> /dev/null; then
        HAPROXY_PATH="$(which haproxy)"
    else
        fatal "Could not locate haproxy binary after installation"
    fi
    info "✓ HAProxy binary: $HAPROXY_PATH"

    # Create HAProxy config directory
    info "Creating HAProxy configuration..."
    mkdir -p "$HOME/.haproxy"

    # Get Tailscale IP for frontend binding
    if [[ -z "$TAILSCALE_IP" ]]; then
        # Try to get it again if we haven't captured it yet
        if command -v tailscale &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1 || echo "")
        fi
    fi

    if [[ -z "$TAILSCALE_IP" ]]; then
        warn "Tailscale IP not detected - HAProxy will bind to *:11434"
        warn "This is less secure. Consider re-running install.sh after connecting Tailscale."
        HAPROXY_BIND_ADDRESS="*:11434"
    else
        HAPROXY_BIND_ADDRESS="${TAILSCALE_IP}:11434"
    fi

    # Generate HAProxy configuration
    cat > "$HOME/.haproxy/haproxy.cfg" <<'HAPROXY_CFG_EOF'
# HAProxy configuration for remote-ollama-proxy
# Provides endpoint allowlisting and defense-in-depth security

global
    log stdout format raw local0 info
    maxconn 4096

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5s
    timeout client  300s
    timeout server  300s

frontend ollama_proxy
HAPROXY_CFG_EOF

    # Add bind address (templated)
    echo "    bind ${HAPROXY_BIND_ADDRESS}" >> "$HOME/.haproxy/haproxy.cfg"

    # Continue with the rest of the config
    cat >> "$HOME/.haproxy/haproxy.cfg" <<'HAPROXY_CFG_EOF'

    # Endpoint allowlist - OpenAI API
    acl openai_chat path_beg /v1/chat/completions
    acl openai_models_list path /v1/models
    acl openai_models_detail path_beg /v1/models/
    acl openai_responses path_beg /v1/responses

    # Endpoint allowlist - Anthropic API
    acl anthropic_messages path_beg /v1/messages

    # Endpoint allowlist - Ollama Native API (metadata only)
    acl ollama_version path /api/version
    acl ollama_tags path /api/tags
    acl ollama_show path /api/show

    # Allow only allowlisted endpoints
    use_backend ollama_backend if openai_chat
    use_backend ollama_backend if openai_models_list
    use_backend ollama_backend if openai_models_detail
    use_backend ollama_backend if openai_responses
    use_backend ollama_backend if anthropic_messages
    use_backend ollama_backend if ollama_version
    use_backend ollama_backend if ollama_tags
    use_backend ollama_backend if ollama_show

    # Default deny - return 403 Forbidden
    default_backend deny_backend

backend ollama_backend
    server ollama 127.0.0.1:11434 check

backend deny_backend
    http-request deny deny_status 403
HAPROXY_CFG_EOF

    info "✓ HAProxy config created at ~/.haproxy/haproxy.cfg"
    info "  Frontend: $HAPROXY_BIND_ADDRESS → Backend: 127.0.0.1:11434"

    # Create HAProxy LaunchAgent plist
    HAPROXY_PLIST_PATH="$HOME/Library/LaunchAgents/com.haproxy.plist"
    info "Creating HAProxy LaunchAgent plist at $HAPROXY_PLIST_PATH..."

    cat > "$HAPROXY_PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.haproxy</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HAPROXY_PATH</string>
        <string>-f</string>
        <string>$HOME/.haproxy/haproxy.cfg</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/haproxy.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/haproxy.stderr.log</string>
</dict>
</plist>
EOF

    info "✓ HAProxy LaunchAgent plist created"

    # Load HAProxy service
    info "Loading HAProxy LaunchAgent..."
    HAPROXY_LABEL="com.haproxy"
    launchctl bootstrap "$LAUNCHD_DOMAIN" "$HAPROXY_PLIST_PATH" || fatal "Failed to load HAProxy LaunchAgent"
    sleep 2
    info "✓ HAProxy LaunchAgent loaded"

    # Verify HAProxy is running
    info "Verifying HAProxy is running..."
    HAPROXY_PID=$(pgrep -f "haproxy.*haproxy.cfg" | head -n1 || echo "")
    if [[ -n "$HAPROXY_PID" ]]; then
        info "✓ HAProxy is running (PID: $HAPROXY_PID)"
    else
        warn "Could not verify HAProxy process - check logs: /tmp/haproxy.stderr.log"
    fi

    # Test proxy forwarding (if Tailscale connected)
    if [[ -n "$TAILSCALE_IP" ]]; then
        info "Testing proxy forwarding..."
        PROXY_TEST=$(curl -sf "http://${TAILSCALE_IP}:11434/v1/models" 2>/dev/null || echo "FAILED")
        if [[ "$PROXY_TEST" == "FAILED" ]] || ! echo "$PROXY_TEST" | grep -q "object"; then
            warn "Proxy forwarding test failed - check HAProxy logs"
        else
            info "✓ Proxy forwarding works: $TAILSCALE_IP:11434 → 127.0.0.1:11434"
        fi
    fi

    info "✓ HAProxy installation complete"
    HAPROXY_INSTALLED="yes"
else
    info "HAProxy installation skipped - using fallback mode"
    warn "⚠  Security notice: Ollama will bind to 0.0.0.0 (all interfaces)"
    warn "   This is less secure but functional. Security relies only on Tailscale ACLs."

    # Update Ollama plist to use 0.0.0.0 (fallback mode)
    info "Updating Ollama to bind to all interfaces..."

    # Stop Ollama service
    launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" 2>/dev/null || true
    sleep 2

    # Recreate plist with 0.0.0.0
    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>$OLLAMA_PATH</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0</string>
        <!-- Optional CORS configuration (uncomment if needed):
        <key>OLLAMA_ORIGINS</key>
        <string>*</string>
        -->
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

    # Reload Ollama service
    launchctl bootstrap "$LAUNCHD_DOMAIN" "$PLIST_PATH" || fatal "Failed to reload Ollama LaunchAgent"
    sleep 3

    # Verify Ollama is still working
    RETRY_COUNT=0
    MAX_RETRIES=10
    OLLAMA_READY=false

    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        if curl -sf http://localhost:11434/v1/models &> /dev/null; then
            OLLAMA_READY=true
            break
        fi
        sleep 2
        RETRY_COUNT=$((RETRY_COUNT + 1))
    done

    if [[ "$OLLAMA_READY" == "true" ]]; then
        info "✓ Ollama restarted and responding"
    else
        fatal "Ollama did not respond after restart. Check logs: /tmp/ollama.stderr.log"
    fi

    HAPROXY_INSTALLED="no"
fi

# Step 13: Tailscale Configuration Instructions
important_section "NEXT STEPS: Tailscale Configuration Required"

if [[ -n "$TAILSCALE_IP" ]]; then
    echo "Your server is running! Complete these 3 configuration steps:"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Step 1: Set Machine Name                                   │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "  Visit: ${BLUE}https://login.tailscale.com/admin/machines${NC}"
    echo -e "  Find this device: ${GREEN}$TAILSCALE_IP${NC}"
    echo -e "  Set machine name to: ${GREEN}remote-ollama-proxy${NC}"
    echo ""
    section_break
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Step 2: Configure ACLs (Access Control)                    │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "  Visit: ${BLUE}https://login.tailscale.com/admin/acls${NC}"
    echo ""
    echo "  1. Click the 'JSON editor' button (top left) to switch to JSON mode"
    echo "  2. Add this to your ACL configuration:"
    echo ""
    cat <<'ACL_EOF'
  {
    "tagOwners": {
      "tag:ai-server": [],
      "tag:ai-client": []
    },
    "acls": [
      {
        "action": "accept",
        "src": ["tag:ai-client"],
        "dst": ["tag:ai-server:11434"]
      }
    ]
  }
ACL_EOF
    echo ""
    echo "  3. After saving the ACL, tag your machines:"
    echo ""
    echo -e "     ${BOLD}For this server:${NC}"
    echo "       • Go back to: https://login.tailscale.com/admin/machines"
    echo -e "       • Find this machine (${GREEN}$TAILSCALE_IP${NC})"
    echo "       • Click three dots menu → 'Edit ACL tags...'"
    echo -e "       • In the 'Tags' field, add: ${GREEN}tag:ai-server${NC}"
    echo "       • Click 'Save'"
    echo ""
    echo -e "     ${BOLD}For client machines:${NC}"
    echo "       • Repeat the same process for each client machine"
    echo -e "       • Add tag: ${GREEN}tag:ai-client${NC}"
    echo ""
    section_break
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ Step 3: (Optional) Pre-pull Models                         │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "  ${BOLD}ollama pull <model-name>${NC}"
    echo ""
    echo "  Popular models:"
    echo "    • ollama pull qwen2.5-coder:32b"
    echo "    • ollama pull deepseek-r1:70b"
    echo "    • ollama pull llama3.2"
    echo ""
else
    warn "Tailscale is not connected yet!"
    echo ""
    echo "After connecting Tailscale, you'll need to:"
    echo "  1. Set machine name: https://login.tailscale.com/admin/machines"
    echo "  2. Configure ACLs: https://login.tailscale.com/admin/acls"
    echo ""
fi

# Final summary
echo ""
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                                                                ║"
echo "║                  ✓  Installation Complete!                    ║"
echo "║                                                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [[ -n "$TAILSCALE_IP" ]]; then
    if [[ "${HAPROXY_INSTALLED:-no}" == "yes" ]]; then
        echo -e "  ✓ HAProxy proxy: ${GREEN}${TAILSCALE_IP}:11434 → 127.0.0.1:11434${NC}"
        echo -e "  ✓ Ollama bound to: ${GREEN}127.0.0.1:11434 (loopback only)${NC}"
    else
        echo -e "  ✓ Ollama running on: ${GREEN}0.0.0.0:11434 (all interfaces)${NC}"
    fi
    echo -e "  ✓ Tailscale connected: ${GREEN}$TAILSCALE_IP${NC}"
    echo -e "  ✓ Auto-start on boot: ${GREEN}enabled${NC}"
    echo ""
    section_break
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ What's Next                                                 │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  1. Complete the 3 Tailscale configuration steps above"
    echo ""
    echo "  2. Install the client on your laptop/desktop:"
    echo ""
    echo -e "     ${BLUE}bash <(curl -fsSL https://raw.githubusercontent.com/henriquefalconer/remote-ollama-proxy/master/client/scripts/install.sh)${NC}"
    echo ""
    echo "  3. Test the connection from your client:"
    echo ""
    echo -e "     ${BLUE}curl http://remote-ollama-proxy:11434/v1/models${NC}"
    echo ""
    section_break
    echo "Troubleshooting commands:"
    echo -e "  • Restart Ollama: ${BLUE}launchctl kickstart -k $LAUNCHD_DOMAIN/$LAUNCHD_LABEL${NC}"
    echo -e "  • View logs:      ${BLUE}tail -f /tmp/ollama.stderr.log${NC}"
    if [[ "${HAPROXY_INSTALLED:-no}" == "yes" ]]; then
        echo -e "  • Restart HAProxy: ${BLUE}launchctl kickstart -k $LAUNCHD_DOMAIN/com.haproxy${NC}"
        echo -e "  • View HAProxy logs: ${BLUE}tail -f /tmp/haproxy.stderr.log${NC}"
    fi
    echo ""
else
    warn "⚠  Tailscale is NOT connected!"
    echo ""
    echo "  Next steps:"
    echo "    1. Connect Tailscale (tailscale up or open GUI app)"
    echo "    2. Re-run this script to complete configuration"
    echo ""
fi
