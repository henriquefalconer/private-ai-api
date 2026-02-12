#!/bin/bash
set -euo pipefail

# self-sovereign-ollama ai-server uninstall script
# Removes the Ollama LaunchAgent service and related configuration
# Source: server/specs/SCRIPTS.md lines 21-29

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
echo "  self-sovereign-ollama ai-server Uninstall"
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

# Step 4: Network configuration cleanup (v2)
echo ""
info "Network configuration cleanup..."
echo ""
warn "Note: This script does NOT automatically revert network settings."
echo ""
echo "If you configured a static IP for the DMZ network during installation,"
echo "you may want to revert it back to DHCP:"
echo ""
echo "  sudo networksetup -listallhardwareports"
echo "  sudo networksetup -setdhcp \"<interface-name>\""
echo ""
echo "Example:"
echo "  sudo networksetup -setdhcp \"Ethernet\""
echo ""
read -p "Would you like to revert the static IP to DHCP now? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Available network interfaces:"
    networksetup -listallhardwareports | grep -A 1 "Hardware Port" | grep -v "^--$"
    echo ""
    read -p "Enter the interface name (e.g., Ethernet): " INTERFACE_NAME
    if [[ -n "$INTERFACE_NAME" ]]; then
        info "Reverting $INTERFACE_NAME to DHCP..."
        if sudo networksetup -setdhcp "$INTERFACE_NAME"; then
            info "✓ Successfully reverted $INTERFACE_NAME to DHCP"
            REMOVED_ITEMS+=("Static IP configuration (reverted to DHCP)")
        else
            error "Failed to revert to DHCP"
            warn "You may need to manually configure this in System Settings"
        fi
    else
        warn "No interface name provided, skipping..."
    fi
else
    info "Skipping static IP reversion (keeping current configuration)"
fi
echo ""

# Step 5: Router configuration reminder (v2)
info "Router configuration cleanup..."
echo ""
warn "Note: This script does NOT modify your router configuration."
echo ""
echo "You should remove this server's WireGuard peer from your router:"
echo "  1. SSH into your OpenWrt router"
echo "  2. Remove the WireGuard peer configuration for this server"
echo "  3. Remove any DMZ firewall rules related to this server"
echo ""
echo "For detailed instructions, see:"
echo "  server/ROUTER_SETUP.md"
echo ""

# Step 7: Document what was left untouched
info "Documenting components left untouched..."
REMAINING_ITEMS+=("Homebrew (if installed)")
REMAINING_ITEMS+=("Ollama binary (installed via Homebrew)")
REMAINING_ITEMS+=("Downloaded models in ~/.ollama/models/ (valuable data preserved)")
REMAINING_ITEMS+=("Network configuration (static IP, if configured)")
REMAINING_ITEMS+=("Router configuration (WireGuard peer, DMZ rules)")

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

info "To clean up router configuration:"
echo "  • SSH into your OpenWrt router"
echo "  • Remove the WireGuard peer for this server"
echo "  • Remove DMZ firewall rules (see server/ROUTER_SETUP.md)"
echo ""

info "The self-sovereign-ollama ai-server has been uninstalled."
echo "You can safely re-run the install script to set it up again."
echo ""
