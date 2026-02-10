#!/bin/bash
set -euo pipefail

# downgrade-claude.sh
# Rollback Claude Code to last known-working version
# Source: client/specs/VERSION_MANAGEMENT.md lines 180-226
# Prerequisite: ~/.ai-client/.version-lock must exist (created by pin-versions.sh)

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

prompt() {
    echo -e "${BLUE}[PROMPT]${NC} $1"
}

# Banner
echo "=== Claude Code Downgrade Tool ==="
echo ""

# Step 1: Check for version lock file
LOCK_FILE="$HOME/.ai-client/.version-lock"

if [[ ! -f "$LOCK_FILE" ]]; then
    error "Version lock file not found: ${LOCK_FILE}"
    echo ""
    echo "You must run pin-versions.sh first to create a version lock:"
    echo "  ./client/scripts/pin-versions.sh"
    echo ""
    exit 1
fi

# Step 2: Read version lock file
info "Reading version lock file..."

# Source the lock file to get variables
source "$LOCK_FILE"

if [[ -z "${CLAUDE_CODE_VERSION:-}" ]]; then
    error "Invalid lock file: CLAUDE_CODE_VERSION not found"
    exit 1
fi

if [[ -z "${CLAUDE_INSTALL_METHOD:-}" ]]; then
    warn "CLAUDE_INSTALL_METHOD not found in lock file, will try to detect"
    CLAUDE_INSTALL_METHOD="unknown"
fi

echo ""
info "Target version from lock file: v${CLAUDE_CODE_VERSION}"
info "Installation method: ${CLAUDE_INSTALL_METHOD}"
echo ""

# Step 3: Get current Claude Code version
if command -v claude &> /dev/null; then
    CURRENT_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")

    if [[ "$CURRENT_VERSION" == "unknown" ]]; then
        warn "Could not detect current Claude Code version"
    else
        info "Current Claude Code version: v${CURRENT_VERSION}"

        # Check if already at target version
        if [[ "$CURRENT_VERSION" == "$CLAUDE_CODE_VERSION" ]]; then
            success "Already at target version v${CLAUDE_CODE_VERSION}"
            echo ""
            echo "No downgrade needed."
            exit 0
        fi
    fi
else
    error "Claude Code not found"
    echo ""
    echo "Install Claude Code first:"
    echo "  npm install -g @anthropic-ai/claude-code"
    exit 1
fi

# Step 4: Confirm downgrade
echo ""
echo "This will downgrade Claude Code to last known working version"
echo "  Current version:  v${CURRENT_VERSION}"
echo "  Target version:   v${CLAUDE_CODE_VERSION}"
echo ""
prompt "Continue? (y/N):"
read -r CONSENT < /dev/tty

if [[ ! "$CONSENT" =~ ^[Yy]$ ]]; then
    info "Downgrade cancelled by user"
    exit 0
fi

echo ""

# Step 5: Attempt downgrade based on installation method
info "Attempting downgrade..."
echo ""

if [[ "$CLAUDE_INSTALL_METHOD" == "npm" ]] || command -v npm &> /dev/null; then
    # Try npm downgrade
    info "Downgrading via npm..."
    echo ""

    if npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"; then
        success "npm downgrade command completed"
    else
        error "npm downgrade failed"
        exit 1
    fi

elif [[ "$CLAUDE_INSTALL_METHOD" == "brew" ]] || command -v brew &> /dev/null; then
    # Homebrew doesn't support easy downgrades
    warn "Homebrew doesn't support easy downgrades"
    echo ""
    echo "Manual steps required:"
    echo ""
    echo "Option 1: Uninstall and reinstall via npm"
    echo "  brew uninstall claude-code"
    echo "  npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"
    echo ""
    echo "Option 2: Homebrew formula downgrade (advanced)"
    echo "  1. brew unlink claude-code"
    echo "  2. Find previous formula commit on GitHub"
    echo "  3. brew install https://raw.githubusercontent.com/.../claude-code.rb"
    echo ""
    info "Recommended: Use Option 1 (npm) for easier version management"
    exit 1

else
    error "Unknown installation method"
    echo ""
    echo "Install Claude Code via npm:"
    echo "  npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"
    exit 1
fi

# Step 6: Verify downgrade
echo ""
info "Verifying downgrade..."

sleep 1  # Give system time to update

NEW_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")

if [[ "$NEW_VERSION" == "$CLAUDE_CODE_VERSION" ]]; then
    echo ""
    success "Successfully downgraded to v${NEW_VERSION}"
    echo ""
    echo "Next steps:"
    echo "  1. Test basic functionality: claude --version"
    echo "  2. Test with Ollama: claude-ollama"
    echo "  3. Check compatibility: ./client/scripts/check-compatibility.sh"
    echo ""
else
    echo ""
    error "Downgrade verification failed"
    echo "  Expected: v${CLAUDE_CODE_VERSION}"
    echo "  Found:    v${NEW_VERSION}"
    echo ""
    echo "Try manually:"
    echo "  npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"
    exit 1
fi
