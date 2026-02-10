#!/bin/bash
set -euo pipefail

# private-ai-client uninstall script
# Removes only client-side changes made by install.sh
# Leaves Tailscale, Homebrew, and pipx untouched
# Source: client/specs/SCRIPTS.md lines 14-18

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

# Banner
echo "================================================"
echo "  private-ai-client Uninstall Script"
echo "================================================"
echo ""

# Step 1: Remove Aider
info "Removing Aider..."
if command -v pipx &> /dev/null; then
    if pipx list 2>/dev/null | grep -q aider-chat; then
        pipx uninstall aider-chat || warn "Failed to uninstall Aider (continuing anyway)"
        info "✓ Aider removed"
    else
        info "Aider not installed via pipx, skipping"
    fi
else
    warn "pipx not found, skipping Aider removal"
fi

# Step 2: Remove shell profile sourcing lines
info "Cleaning shell profile(s)..."

MARKER_START="# >>> private-ai-client >>>"
MARKER_END="# <<< private-ai-client <<<"
REMOVED_COUNT=0

# Clean both zsh and bash profiles (user may have switched shells)
for PROFILE in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$PROFILE" ]]; then
        if grep -q "$MARKER_START" "$PROFILE"; then
            # Remove everything between markers (inclusive)
            # Use sed with temporary file for portability
            sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$PROFILE"
            rm -f "$PROFILE.bak"
            info "✓ Cleaned: $PROFILE"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    fi
done

if [[ $REMOVED_COUNT -eq 0 ]]; then
    info "No shell profile modifications found, skipping"
fi

# Step 3: Delete ~/.private-ai-client directory
info "Removing configuration directory..."
CLIENT_DIR="$HOME/.private-ai-client"
if [[ -d "$CLIENT_DIR" ]]; then
    rm -rf "$CLIENT_DIR"
    info "✓ Removed: $CLIENT_DIR"
else
    info "Configuration directory not found, skipping"
fi

# Summary
echo ""
echo "================================================"
echo "  Uninstall Complete!"
echo "================================================"
echo ""
info "Removed:"
echo "  - Aider (via pipx)"
echo "  - $CLIENT_DIR"
echo "  - Shell profile modifications"
echo ""
info "Preserved (as expected):"
echo "  - Tailscale"
echo "  - Homebrew"
echo "  - pipx"
echo "  - Python"
echo ""
echo "Changes will take effect in new terminal sessions."
echo "Current terminal may still have old environment variables loaded."
echo ""
