#!/bin/bash
set -euo pipefail

# private-ai-client install script
# Configures environment to connect to private-ai-server via Tailscale
# Works both from local clone and via curl-pipe installation
# Source: client/specs/* and client/SETUP.md

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

# Banner
echo "================================================"
echo "  private-ai-client Installation Script"
echo "================================================"
echo ""

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
        info "Installing Python 3 via Homebrew..."
        brew install python3 || fatal "Failed to install Python"
    fi
else
    info "Installing Python 3 via Homebrew..."
    brew install python3 || fatal "Failed to install Python"
fi

# Step 5: Check/install Tailscale
info "Checking for Tailscale..."
if ! command -v tailscale &> /dev/null; then
    info "Installing Tailscale via Homebrew..."
    brew install tailscale || fatal "Failed to install Tailscale"
fi
info "✓ Tailscale installed"

# Open Tailscale app for login
info "Opening Tailscale for login and device approval..."
open -a Tailscale || warn "Could not open Tailscale app automatically. Please open it manually."

# Wait for Tailscale connection
info "Waiting for Tailscale connection (up to 60 seconds)..."
WAIT_COUNT=0
MAX_WAIT=60
TAILSCALE_CONNECTED=false
while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    if tailscale status &> /dev/null && tailscale ip -4 &> /dev/null; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
        if [[ -n "$TAILSCALE_IP" ]]; then
            info "✓ Tailscale connected! IP: $TAILSCALE_IP"
            TAILSCALE_CONNECTED=true
            break
        fi
    fi
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [[ "$TAILSCALE_CONNECTED" == "false" ]]; then
    warn "Tailscale did not connect within 60 seconds"
    echo "Please ensure you complete the Tailscale login process"
    echo "You can continue installation, but connectivity test will fail"
    echo ""
fi

# Step 6: Prompt for server hostname
echo ""
prompt "Enter the server hostname (default: private-ai-server):"
read -r SERVER_HOSTNAME
if [[ -z "$SERVER_HOSTNAME" ]]; then
    SERVER_HOSTNAME="private-ai-server"
fi
info "Using server hostname: $SERVER_HOSTNAME"

# Step 7: Create ~/.private-ai-client directory
info "Creating configuration directory..."
CLIENT_DIR="$HOME/.private-ai-client"
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
# private-ai-client environment configuration
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
    MARKER_START="# >>> private-ai-client >>>"
    MARKER_END="# <<< private-ai-client <<<"

    # Check if markers already exist
    if grep -q "$MARKER_START" "$SHELL_PROFILE" 2>/dev/null; then
        info "Shell profile already configured (markers found), skipping"
    else
        # Create profile if it doesn't exist
        touch "$SHELL_PROFILE"

        # Append sourcing block with markers
        cat >> "$SHELL_PROFILE" <<PROFILE_EOF

$MARKER_START
# private-ai-client environment configuration
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

# Step 10: Install pipx
info "Checking for pipx..."
if ! command -v pipx &> /dev/null; then
    info "Installing pipx via Homebrew..."
    brew install pipx || fatal "Failed to install pipx"

    # Run ensurepath immediately
    info "Running pipx ensurepath..."
    pipx ensurepath || warn "pipx ensurepath failed (non-fatal)"
else
    info "✓ pipx already installed"
fi

# Step 11: Install Aider
info "Installing Aider via pipx..."
if pipx list 2>/dev/null | grep -q aider-chat; then
    info "✓ Aider already installed, upgrading..."
    pipx upgrade aider-chat || warn "Failed to upgrade Aider (non-fatal)"
else
    pipx install aider-chat || fatal "Failed to install Aider"
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
    UNINSTALL_URL="https://raw.githubusercontent.com/henriquefalconer/private-ai-api/master/client/scripts/uninstall.sh"
    if curl -fsSL "$UNINSTALL_URL" -o "$UNINSTALL_SCRIPT"; then
        chmod +x "$UNINSTALL_SCRIPT"
        info "✓ Downloaded uninstall.sh from GitHub"
    else
        warn "Failed to download uninstall.sh (non-fatal)"
        warn "Uninstall script will not be available"
    fi
fi

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
    echo "  1. Server is not running yet (install private-ai-server first)"
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
echo "IMPORTANT: Open a new terminal or run:"
echo "  source $SHELL_PROFILE"
echo ""
echo "Then start using Aider:"
echo "  aider              # Interactive mode"
echo "  aider --yes        # Auto-accept mode"
echo ""
echo "Environment variables set:"
echo "  OLLAMA_API_BASE=http://$SERVER_HOSTNAME:11434/v1"
echo "  OPENAI_API_BASE=http://$SERVER_HOSTNAME:11434/v1"
echo "  OPENAI_API_KEY=ollama"
echo ""
echo "To uninstall: $UNINSTALL_SCRIPT"
echo ""
