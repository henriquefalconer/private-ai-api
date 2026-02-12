#!/bin/bash
set -euo pipefail

# self-sovereign-ollama ai-client uninstall script
# Removes only client-side changes made by install.sh
# Leaves WireGuard, Homebrew, and pipx untouched
# Source: client/specs/SCRIPTS.md lines 14-18

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

# Banner
echo "================================================"
echo "  self-sovereign-ollama ai-client Uninstall"
echo "  Removes client-side changes and configuration"
echo "================================================"
echo ""

# Track what was actually removed
REMOVED_ITEMS=()
REMOVAL_FAILURES=()

# Step 1: Remove Aider
info "Removing Aider..."
if command -v pipx &> /dev/null; then
    if pipx list 2>/dev/null | grep -q aider-chat; then
        if pipx uninstall aider-chat > /dev/null 2>&1; then
            info "✓ Aider removed"
            REMOVED_ITEMS+=("Aider (via pipx)")
        else
            warn "Failed to uninstall Aider (continuing anyway)"
            REMOVAL_FAILURES+=("Aider (pipx uninstall failed)")
        fi
    else
        info "Aider not installed via pipx, skipping"
    fi
else
    warn "pipx not found, skipping Aider removal"
fi

# Step 2: Remove shell profile sourcing lines and v2+ aliases
info "Cleaning shell profile(s)..."

# v1 markers (environment sourcing)
MARKER_START="# >>> ai-client >>>"
MARKER_END="# <<< ai-client <<<"

# v2+ markers (Claude Code alias)
CLAUDE_MARKER_START="# >>> claude-ollama >>>"
CLAUDE_MARKER_END="# <<< claude-ollama <<<"

REMOVED_COUNT=0

# Clean both zsh and bash profiles (user may have switched shells)
for PROFILE in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$PROFILE" ]]; then
        PROFILE_MODIFIED=false

        # Remove v1 markers (environment sourcing)
        if grep -q "$MARKER_START" "$PROFILE"; then
            sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$PROFILE"
            rm -f "$PROFILE.bak"
            PROFILE_MODIFIED=true
        fi

        # Remove v2+ markers (Claude Code alias)
        if grep -q "$CLAUDE_MARKER_START" "$PROFILE"; then
            sed -i.bak "/$CLAUDE_MARKER_START/,/$CLAUDE_MARKER_END/d" "$PROFILE"
            rm -f "$PROFILE.bak"
            PROFILE_MODIFIED=true
        fi

        if [[ "$PROFILE_MODIFIED" == "true" ]]; then
            info "✓ Cleaned: $PROFILE"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    fi
done

if [[ $REMOVED_COUNT -gt 0 ]]; then
    REMOVED_ITEMS+=("Shell profile modifications ($REMOVED_COUNT file(s))")
else
    info "No shell profile modifications found, skipping"
fi

# Step 3: WireGuard cleanup (v2)
info "WireGuard VPN cleanup..."
echo ""

# Display public key before deletion (for router admin coordination)
WG_PUBKEY_FILE="$HOME/.ai-client/wireguard/publickey"
if [[ -f "$WG_PUBKEY_FILE" ]]; then
    WG_PUBKEY=$(cat "$WG_PUBKEY_FILE" 2>/dev/null || echo "")
    if [[ -n "$WG_PUBKEY" ]]; then
        warn "Your WireGuard public key (save this for reference):"
        echo "  $WG_PUBKEY"
        echo ""
    fi
fi

# Prompt for WireGuard tools removal
echo "WireGuard configuration will be removed with ~/.ai-client directory."
read -p "Would you like to also remove WireGuard tools? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v brew &> /dev/null && brew list wireguard-tools &> /dev/null 2>&1; then
        info "Removing WireGuard tools..."
        if brew uninstall wireguard-tools > /dev/null 2>&1; then
            info "✓ WireGuard tools removed"
            REMOVED_ITEMS+=("WireGuard tools (via Homebrew)")
        else
            warn "Failed to remove WireGuard tools (continuing anyway)"
            REMOVAL_FAILURES+=("WireGuard tools (brew uninstall failed)")
        fi
    else
        info "WireGuard tools not installed via Homebrew, skipping"
    fi
else
    info "Keeping WireGuard tools installed"
fi
echo ""

# Step 4: Delete ~/.ai-client directory
info "Removing configuration directory..."
CLIENT_DIR="$HOME/.ai-client"
if [[ -d "$CLIENT_DIR" ]]; then
    rm -rf "$CLIENT_DIR"
    info "✓ Removed: $CLIENT_DIR"
    REMOVED_ITEMS+=("Configuration directory ($CLIENT_DIR)")
    REMOVED_ITEMS+=("WireGuard configuration files (in $CLIENT_DIR/wireguard/)")
else
    info "Configuration directory not found, skipping"
fi

# Summary
echo ""
echo "================================================"
echo "  Uninstall Complete!"
echo "================================================"
echo ""

# Show what was actually removed
if [[ ${#REMOVED_ITEMS[@]} -gt 0 ]]; then
    info "Successfully removed:"
    for item in "${REMOVED_ITEMS[@]}"; do
        echo "  - $item"
    done
    echo ""
else
    info "Nothing was removed (clean system or already uninstalled)"
    echo ""
fi

# Show any failures
if [[ ${#REMOVAL_FAILURES[@]} -gt 0 ]]; then
    warn "Removal failures:"
    for failure in "${REMOVAL_FAILURES[@]}"; do
        echo "  - $failure"
    done
    echo ""
fi

info "Preserved (as expected):"
if [[ ! $REPLY =~ ^[Yy]$ ]] || ! command -v brew &> /dev/null; then
    echo "  - WireGuard tools (if installed)"
fi
echo "  - Homebrew"
echo "  - pipx"
echo "  - Python"
echo ""

# Router cleanup reminder
if [[ -n "${WG_PUBKEY:-}" ]]; then
    warn "Important: Router Configuration Cleanup"
    echo "  Ask your router administrator to remove this VPN peer:"
    echo "  Public key: $WG_PUBKEY"
    echo ""
    echo "  This will revoke your VPN access to the ai-server."
    echo ""
fi

# Terminal reload reminder (inside summary box)
if [[ ${#REMOVED_ITEMS[@]} -gt 0 ]]; then
    info "Important:"
    echo "  Close and reopen your terminal, or run: exec \$SHELL"
    echo "  (Changes will take effect in new terminal sessions)"
fi

echo "================================================"
echo ""
