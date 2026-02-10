#!/bin/bash
set -euo pipefail

# private-ai-server install script
# Automates the setup of Ollama + Tailscale for private LLM inference
# Source: server/specs/* and server/SETUP.md

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Banner
echo "================================================"
echo "  private-ai-server Installation Script"
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
info "✓ macOS $MACOS_VERSION with Apple Silicon detected"

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

# Try to install GUI app via cask if neither CLI nor GUI app exists
if ! command -v tailscale &> /dev/null && ! [ -d "/Applications/Tailscale.app" ]; then
    info "Installing Tailscale GUI via Homebrew..."
    brew install --cask tailscale || fatal "Failed to install Tailscale"
    info "✓ Tailscale GUI installed"
elif [ -d "/Applications/Tailscale.app" ]; then
    info "✓ Tailscale GUI already installed"
elif command -v tailscale &> /dev/null; then
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
        echo "Please complete these steps in the Tailscale GUI:"
        echo "  1. Click 'Log in' or 'Sign up'"
        echo "  2. Authenticate in your browser"
        echo "  3. Approve the device in your Tailscale admin"
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

    # Wait with interactive prompt
    info "Waiting for Tailscale connection..."
    echo "Checking status every 3 seconds (press Enter to check immediately, Ctrl+C to abort)"
    echo ""

    CONNECTED=false
    CHECK_COUNT=0
    MAX_CHECKS=100  # 5 minutes maximum (100 * 3 seconds)

    while [[ "$CONNECTED" == "false" ]] && [[ $CHECK_COUNT -lt $MAX_CHECKS ]]; do
        # Check status
        if command -v tailscale &> /dev/null && tailscale status &> /dev/null 2>&1; then
            POTENTIAL_IP=$(tailscale ip -4 2>/dev/null | head -n1)
            if [[ -n "$POTENTIAL_IP" ]]; then
                TAILSCALE_IP="$POTENTIAL_IP"
                CONNECTED=true
                echo ""
                info "✓ Tailscale connected! IP: $TAILSCALE_IP"
                echo ""
                break
            fi
        fi

        # Wait with timeout or Enter
        if read -t 3 -r 2>/dev/null; then
            continue  # User pressed Enter, check immediately
        fi
        echo -n "."  # Show progress dot
        CHECK_COUNT=$((CHECK_COUNT + 1))
    done

    if [[ "$CONNECTED" == "false" ]]; then
        echo ""
        warn "Tailscale did not connect within the timeout period"
        echo "Please ensure you complete the Tailscale login process and re-run this script"
        echo "You can check status manually with: tailscale status"
        echo ""
    fi
fi

# Step 4: Check/install Ollama
info "Checking for Ollama..."
if ! command -v ollama &> /dev/null; then
    info "Installing Ollama via Homebrew..."
    brew install ollama || fatal "Failed to install Ollama"
fi
info "✓ Ollama installed: $(ollama --version 2>/dev/null || echo 'version unknown')"

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

# Step 12: Prompt for Tailscale machine name
echo ""
echo "================================================"
echo "  Tailscale Configuration"
echo "================================================"
echo ""

if [[ -n "$TAILSCALE_IP" ]]; then
    info "It is recommended to set a custom machine name in Tailscale admin console"
    echo "  Default recommendation: 'private-ai-server'"
    echo "  Current Tailscale IP: $TAILSCALE_IP"
    echo ""
    echo "To set the machine name:"
    echo "  1. Visit https://login.tailscale.com/admin/machines"
    echo "  2. Find this device (IP: $TAILSCALE_IP)"
    echo "  3. Click the three dots menu → 'Edit machine...'"
    echo "  4. Set 'Machine name' to 'private-ai-server' (or your preferred name)"
    echo ""
else
    warn "Tailscale is not connected - skipping machine name configuration"
    echo "  After connecting Tailscale, you can set the machine name at:"
    echo "  https://login.tailscale.com/admin/machines"
    echo ""
fi

# Step 13: Print Tailscale ACL instructions
echo "================================================"
echo "  Tailscale ACL Configuration"
echo "================================================"
echo ""
info "Add the following ACL rule to your Tailscale admin console:"
echo ""
echo "Visit: https://login.tailscale.com/admin/acls"
echo ""
echo "Add to your ACL configuration:"
cat <<'ACL_EOF'

{
  "tagOwners": {
    "tag:private-ai-server": [],
    "tag:ai-client": []
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ai-client"],
      "dst": ["tag:private-ai-server:11434"]
    }
  ]
}
ACL_EOF
echo ""
info "After adding the ACL:"
echo "  1. Tag this server machine with 'tag:private-ai-server'"
echo "  2. Tag authorized client machines with 'tag:ai-client'"
echo ""

# Final summary
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
info "✓ Ollama is running and listening on all interfaces (0.0.0.0:11434)"

if [[ -n "$TAILSCALE_IP" ]]; then
    info "✓ Tailscale is connected (IP: $TAILSCALE_IP)"
else
    warn "⚠ Tailscale is NOT connected - you must connect before clients can reach this server"
    echo "  Connect with: tailscale up"
    echo "  Or open the Tailscale GUI app"
    echo ""
fi

info "✓ LaunchAgent will auto-start Ollama on boot"
echo ""
echo "Next steps:"

if [[ -n "$TAILSCALE_IP" ]]; then
    echo "  1. Set machine name to 'private-ai-server' in Tailscale admin console"
    echo "  2. Configure Tailscale ACLs (see instructions above)"
    echo "  3. Tag this machine with 'tag:private-ai-server'"
    echo "  4. (Optional) Pre-pull models: ollama pull <model-name>"
    echo "  5. Test from a client: curl http://private-ai-server:11434/v1/models"
else
    echo "  1. Connect Tailscale (tailscale up or open GUI app)"
    echo "  2. Re-run this script to complete Tailscale configuration"
    echo "  3. Or manually configure: set machine name and ACLs at https://login.tailscale.com/admin"
fi

echo ""
echo "To restart Ollama: launchctl kickstart -k $LAUNCHD_DOMAIN/$LAUNCHD_LABEL"
echo "To view logs: tail -f /tmp/ollama.stderr.log"
echo ""
