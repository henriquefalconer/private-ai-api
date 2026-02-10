#!/bin/bash
set -euo pipefail

# private-ai-server uninstall script
# Removes the Ollama LaunchAgent service and related configuration
# Source: server/specs/SCRIPTS.md lines 21-29

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
echo "  private-ai-server Uninstall Script"
echo "================================================"
echo ""

# Track what we remove
REMOVED_ITEMS=()
REMAINING_ITEMS=()

# Step 1: Stop the Ollama LaunchAgent service
info "Stopping Ollama LaunchAgent service..."
LAUNCHD_DOMAIN="gui/$(id -u)"
LAUNCHD_LABEL="com.ollama"

if launchctl print "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" &> /dev/null; then
    info "Service is currently loaded, stopping..."
    if launchctl bootout "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" 2>/dev/null; then
        info "✓ Service stopped successfully"
        REMOVED_ITEMS+=("Ollama LaunchAgent service (stopped and unloaded)")
    else
        warn "Failed to stop service gracefully, but continuing..."
        REMOVED_ITEMS+=("Ollama LaunchAgent service (attempted to stop)")
    fi
else
    info "Service was not loaded (already stopped or never started)"
fi

# Give the service time to fully stop
sleep 2

# Step 2: Remove the plist file
PLIST_PATH="$HOME/Library/LaunchAgents/com.ollama.plist"
info "Removing LaunchAgent plist..."

if [[ -f "$PLIST_PATH" ]]; then
    rm -f "$PLIST_PATH"
    info "✓ Removed plist file: $PLIST_PATH"
    REMOVED_ITEMS+=("LaunchAgent plist file ($PLIST_PATH)")
else
    info "Plist file not found (already removed or never created)"
fi

# Step 3: Optionally clean up log files
info "Cleaning up Ollama log files..."
LOG_FILES=(
    "/tmp/ollama.stdout.log"
    "/tmp/ollama.stderr.log"
)

LOGS_REMOVED=0
for LOG_FILE in "${LOG_FILES[@]}"; do
    if [[ -f "$LOG_FILE" ]]; then
        rm -f "$LOG_FILE"
        info "✓ Removed log file: $LOG_FILE"
        LOGS_REMOVED=$((LOGS_REMOVED + 1))
    fi
done

if [[ $LOGS_REMOVED -gt 0 ]]; then
    REMOVED_ITEMS+=("Ollama log files ($LOGS_REMOVED files from /tmp/)")
else
    info "No log files found to remove"
fi

# Step 4: Document what was left untouched
info "Documenting components left untouched..."
REMAINING_ITEMS+=("Homebrew (if installed)")
REMAINING_ITEMS+=("Tailscale (if installed)")
REMAINING_ITEMS+=("Ollama binary (installed via Homebrew)")
REMAINING_ITEMS+=("Downloaded models in ~/.ollama/models/ (valuable data preserved)")

# Verify the model directory still exists
if [[ -d "$HOME/.ollama/models" ]]; then
    MODEL_COUNT=$(find "$HOME/.ollama/models" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$MODEL_COUNT" -gt 0 ]]; then
        info "✓ Preserved $MODEL_COUNT model files in ~/.ollama/models/"
    fi
fi

# Final summary
echo ""
echo "================================================"
echo "  Uninstall Complete"
echo "================================================"
echo ""

if [[ ${#REMOVED_ITEMS[@]} -gt 0 ]]; then
    echo -e "${GREEN}Removed:${NC}"
    for item in "${REMOVED_ITEMS[@]}"; do
        echo "  • $item"
    done
    echo ""
fi

echo -e "${YELLOW}Left untouched:${NC}"
for item in "${REMAINING_ITEMS[@]}"; do
    echo "  • $item"
done
echo ""

info "To completely remove Ollama and its data:"
echo "  • Uninstall Ollama binary: brew uninstall ollama"
echo "  • Remove model data: rm -rf ~/.ollama"
echo ""

info "To uninstall Tailscale:"
echo "  • brew uninstall tailscale"
echo ""

info "The private-ai-server has been uninstalled."
echo "You can safely re-run the install script to set it up again."
echo ""
