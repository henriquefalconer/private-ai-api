#!/bin/bash
set -euo pipefail

# ai-client install script
# Configures environment to connect to ai-server via Tailscale
# Works both from local clone and via curl-pipe installation
# Source: client/specs/* and client/SETUP.md

# Suppress Homebrew noise
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

prompt() {
    echo -e "${BLUE}[PROMPT]${NC} $1"
}

section_break() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ -n "${1:-}" ]]; then
        echo "  $1"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    echo ""
}

# Banner
echo "================================================"
echo "  ai-client Installation Script"
echo "================================================"
echo ""

section_break "System Requirements Check"

# Step 1: Detect macOS 14+ (Sonoma)
info "Checking system requirements..."
if [[ "$(uname)" != "Darwin" ]]; then
    fatal "This script requires macOS. Detected: $(uname)"
fi

MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 14 ]]; then
    fatal "This script requires macOS 14 (Sonoma) or later. Detected: $MACOS_VERSION"
fi
info "✓ macOS $MACOS_VERSION detected"

# Step 2: Detect user's shell
info "Detecting shell..."
USER_SHELL=$(basename "$SHELL")
if [[ "$USER_SHELL" != "zsh" && "$USER_SHELL" != "bash" ]]; then
    warn "Detected shell: $USER_SHELL (expected zsh or bash)"
    USER_SHELL="zsh"  # Default to zsh on modern macOS
fi

if [[ "$USER_SHELL" == "zsh" ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [[ "$USER_SHELL" == "bash" ]]; then
    SHELL_PROFILE="$HOME/.bashrc"
fi
info "✓ Shell detected: $USER_SHELL (profile: $SHELL_PROFILE)"

section_break "Dependency Installation"

# Step 3: Check for Homebrew
info "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    warn "Homebrew not found"
    echo "Please install Homebrew from https://brew.sh and re-run this script"
    fatal "Homebrew is required"
fi
info "✓ Homebrew found: $(brew --version | head -n1)"

# Step 4: Check/install Python 3.10+
info "Checking for Python 3.10+..."
PYTHON_VERSION=""
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

    if [[ "$PYTHON_MAJOR" -ge 3 && "$PYTHON_MINOR" -ge 10 ]]; then
        info "✓ Python $PYTHON_VERSION found"
    else
        warn "Python $PYTHON_VERSION is too old (need 3.10+)"
        info "Installing Python 3 via Homebrew (this may take a minute)..."
        brew install python3 > /tmp/python3-install.log 2>&1 || fatal "Failed to install Python"
        info "✓ Python 3 installed"
    fi
else
    info "Installing Python 3 via Homebrew (this may take a minute)..."
    brew install python3 > /tmp/python3-install.log 2>&1 || fatal "Failed to install Python"
    info "✓ Python 3 installed"
fi

# Step 5: Check/install Tailscale
info "Checking for Tailscale..."

# Check if Tailscale GUI is installed
if ! [ -d "/Applications/Tailscale.app" ]; then
    info "Installing Tailscale GUI via Homebrew..."
    brew install --cask tailscale > /tmp/tailscale-gui-install.log 2>&1 || fatal "Failed to install Tailscale GUI"
    info "✓ Tailscale GUI installed"
else
    info "✓ Tailscale GUI already installed"
fi

# Check if Tailscale CLI is available
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
        read -r -p "Press Enter to check connection status (or Ctrl+C to exit and run script later)... "

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

section_break "Environment Configuration"

# Step 6: Prompt for server hostname
echo ""
prompt "Enter the server hostname (default: ai-server):"
read -r SERVER_HOSTNAME
if [[ -z "$SERVER_HOSTNAME" ]]; then
    SERVER_HOSTNAME="ai-server"
fi
info "Using server hostname: $SERVER_HOSTNAME"

# Step 7: Create ~/.ai-client directory
info "Creating configuration directory..."
CLIENT_DIR="$HOME/.ai-client"
mkdir -p "$CLIENT_DIR"
info "✓ Created: $CLIENT_DIR"

# Step 8: Generate environment file from template
info "Generating environment configuration..."

# Dual-mode strategy: local clone vs curl-pipe
ENV_TEMPLATE_CONTENT=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
LOCAL_TEMPLATE="$SCRIPT_DIR/../config/env.template"

# Detect curl-pipe mode: $0 is bash/stdin or template doesn't exist
if [[ "$0" == "bash" || "$0" == "/dev/stdin" || ! -f "$LOCAL_TEMPLATE" ]]; then
    # Curl-pipe mode: use embedded template
    info "Using embedded env.template (curl-pipe mode)"
    ENV_TEMPLATE_CONTENT=$(cat <<'TEMPLATE_EOF'
# ai-client environment configuration
# Source: client/specs/API_CONTRACT.md
# Generated from env.template by install.sh -- do not edit manually
export OLLAMA_API_BASE=http://__HOSTNAME__:11434/v1
export OPENAI_API_BASE=http://__HOSTNAME__:11434/v1
export OPENAI_API_KEY=ollama
# export AIDER_MODEL=ollama/<model-name>
TEMPLATE_EOF
)
else
    # Local clone mode: read from file
    info "Using env.template from local clone"
    ENV_TEMPLATE_CONTENT=$(cat "$LOCAL_TEMPLATE")
fi

# Substitute __HOSTNAME__ placeholder
ENV_FILE="$CLIENT_DIR/env"
echo "$ENV_TEMPLATE_CONTENT" | sed "s/__HOSTNAME__/$SERVER_HOSTNAME/g" > "$ENV_FILE"
info "✓ Created: $ENV_FILE"

# Step 9: Prompt for shell profile modification consent
echo ""
prompt "Update $SHELL_PROFILE to source the environment? (required for tools to work) [Y/n]:"
read -r CONSENT
CONSENT=${CONSENT:-Y}
if [[ "$CONSENT" =~ ^[Yy]$ ]]; then
    info "Updating shell profile..."

    # Marker pattern for idempotency and clean removal
    MARKER_START="# >>> ai-client >>>"
    MARKER_END="# <<< ai-client <<<"

    # Check if markers already exist
    if grep -q "$MARKER_START" "$SHELL_PROFILE" 2>/dev/null; then
        info "Shell profile already configured (markers found), skipping"
    else
        # Create profile if it doesn't exist
        touch "$SHELL_PROFILE"

        # Append sourcing block with markers
        cat >> "$SHELL_PROFILE" <<PROFILE_EOF

$MARKER_START
# ai-client environment configuration
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi
$MARKER_END
PROFILE_EOF
        info "✓ Updated: $SHELL_PROFILE"
    fi
else
    warn "Shell profile not updated. You must manually source $ENV_FILE before using tools"
fi

section_break "Tool Installation"

# Step 10: Install pipx
info "Checking for pipx..."
if ! command -v pipx &> /dev/null; then
    info "Installing pipx via Homebrew (this may take a minute)..."
    brew install pipx > /tmp/pipx-install.log 2>&1 || fatal "Failed to install pipx"
    info "✓ pipx installed"
else
    info "✓ pipx already installed"
fi

# Always run ensurepath to ensure PATH is configured
info "Running pipx ensurepath..."
pipx ensurepath || warn "pipx ensurepath failed (non-fatal)"

# Step 11: Install Aider
info "Checking for Aider..."
if pipx list 2>/dev/null | grep -q aider-chat; then
    info "✓ Aider already installed, upgrading..."
    pipx upgrade aider-chat > /tmp/aider-upgrade.log 2>&1 || warn "Failed to upgrade Aider (non-fatal)"
else
    info "Installing Aider via pipx (this may take a minute)..."
    pipx install aider-chat > /tmp/aider-install.log 2>&1 || fatal "Failed to install Aider"
    info "✓ Aider installed"
fi

# Step 12: Copy uninstall.sh for curl-pipe users
info "Installing uninstall script..."
UNINSTALL_SCRIPT="$CLIENT_DIR/uninstall.sh"

# Detect if we have local uninstall.sh
LOCAL_UNINSTALL="$SCRIPT_DIR/uninstall.sh"
if [[ -f "$LOCAL_UNINSTALL" ]]; then
    # Local clone mode: copy from repo
    cp "$LOCAL_UNINSTALL" "$UNINSTALL_SCRIPT"
    chmod +x "$UNINSTALL_SCRIPT"
    info "✓ Copied uninstall.sh from local clone"
else
    # Curl-pipe mode: download from GitHub
    info "Downloading uninstall.sh from GitHub..."
    UNINSTALL_URL="https://raw.githubusercontent.com/henriquefalconer/remote-ollama/master/client/scripts/uninstall.sh"
    if curl -fsSL "$UNINSTALL_URL" -o "$UNINSTALL_SCRIPT"; then
        chmod +x "$UNINSTALL_SCRIPT"
        info "✓ Downloaded uninstall.sh from GitHub"
    else
        warn "Failed to download uninstall.sh (non-fatal)"
        warn "Uninstall script will not be available"
    fi
fi

section_break "Connectivity Test"

# Step 13: Run connectivity test
echo ""
info "Running connectivity test..."
TEST_URL="http://$SERVER_HOSTNAME:11434/v1/models"
if curl -sf --max-time 5 "$TEST_URL" &> /dev/null; then
    info "✓ Successfully connected to server!"
    info "  Server: $TEST_URL"
else
    warn "Could not connect to server at $TEST_URL"
    echo ""
    echo "Possible reasons:"
    echo "  1. Server is not running yet (install ai-server first)"
    echo "  2. Tailscale ACLs not configured (check admin console)"
    echo "  3. This device not tagged with 'tag:ai-client'"
    echo "  4. Server hostname '$SERVER_HOSTNAME' is incorrect"
    echo ""
    echo "You can continue to use the client once the server is accessible."
    echo ""
fi

# Final summary
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
info "✓ Environment configured: $ENV_FILE"
info "✓ Shell profile updated: $SHELL_PROFILE"
info "✓ Aider installed via pipx"
info "✓ Uninstall script: $UNINSTALL_SCRIPT"
echo ""
echo "IMPORTANT: Reload your shell configuration:"
echo "  exec \$SHELL          # Restart shell (recommended)"
echo "  OR: source $SHELL_PROFILE"
echo ""
echo "Then start using Aider:"
echo "  aider              # Interactive mode"
echo "  aider --yes        # Auto-accept mode"
echo ""
echo "Environment variables configured:"
echo "  OLLAMA_API_BASE=http://$SERVER_HOSTNAME:11434/v1"
echo "  OPENAI_API_BASE=http://$SERVER_HOSTNAME:11434/v1"
echo "  OPENAI_API_KEY=ollama"
echo ""
echo "Optional: Set default model for Aider"
echo "  Uncomment and configure AIDER_MODEL in: $ENV_FILE"
echo "  Example: export AIDER_MODEL=ollama/qwen2.5-coder:32b"
echo ""
echo "Troubleshooting Resources:"
echo "  • Server setup: See server/README.md in the repository"
echo "  • Tailscale issues: https://tailscale.com/kb/1023/troubleshooting"
echo "  • Aider documentation: https://aider.chat/docs/"
echo "  • Check logs: /tmp/python3-install.log, /tmp/aider-install.log"
echo ""
echo "To uninstall: $UNINSTALL_SCRIPT"
echo ""
