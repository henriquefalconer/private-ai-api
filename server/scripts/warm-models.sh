#!/bin/bash
set -euo pipefail

# private-ai-server model warming script
# Pre-loads specified models into memory for faster first-request latency
# Source: server/specs/FUNCTIONALITIES.md line 17-19

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

# Usage check
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <model1> [model2] [model3] ..."
    echo ""
    echo "Examples:"
    echo "  $0 qwen2.5-coder:32b"
    echo "  $0 qwen2.5-coder:32b deepseek-r1:70b llama3.2-vision:90b"
    echo ""
    echo "This script will:"
    echo "  1. Pull each model (if not already present)"
    echo "  2. Send a minimal inference request to load model into memory"
    echo "  3. Continue on individual model failures"
    echo ""
    echo "To wire this into launchd for automatic warmup at boot:"
    echo "  Add a StartCalendarInterval to com.ollama.plist, or create a"
    echo "  separate LaunchAgent that runs after com.ollama has loaded."
    exit 1
fi

# Banner
echo "================================================"
echo "  Model Warming Script"
echo "================================================"
echo ""
info "Models to warm: $*"
echo ""

# Verify Ollama is running
info "Checking if Ollama is running..."
if ! curl -sf http://localhost:11434/v1/models &> /dev/null; then
    error "Ollama is not responding on localhost:11434"
    error "Please ensure Ollama is running and try again"
    exit 1
fi
info "✓ Ollama is running"
echo ""

# Track results
TOTAL_MODELS=$#
SUCCESS_COUNT=0
FAILED_MODELS=()

# Process each model
for MODEL in "$@"; do
    echo "----------------------------------------"
    info "Processing model: $MODEL"

    # Step 1: Pull model
    info "Pulling model (if not present)..."
    if ollama pull "$MODEL" 2>&1 | grep -q "success"; then
        info "✓ Model pulled: $MODEL"
    else
        # Check if model already exists
        if ollama list 2>&1 | grep -q "$MODEL"; then
            info "✓ Model already present: $MODEL"
        else
            error "Failed to pull model: $MODEL"
            FAILED_MODELS+=("$MODEL (pull failed)")
            continue
        fi
    fi

    # Step 2: Send minimal inference request to load into memory
    info "Loading model into memory..."
    RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$MODEL\",
            \"messages\": [{\"role\": \"user\", \"content\": \"hi\"}],
            \"max_tokens\": 1
        }" 2>&1 || echo "FAILED")

    if [[ "$RESPONSE" == "FAILED" ]] || ! echo "$RESPONSE" | grep -q "choices"; then
        error "Failed to load model into memory: $MODEL"
        FAILED_MODELS+=("$MODEL (load failed)")
        continue
    fi

    info "✓ Model loaded into memory: $MODEL"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    echo ""
done

# Summary
echo "================================================"
echo "  Summary"
echo "================================================"
echo ""
info "Total models: $TOTAL_MODELS"
info "Successfully warmed: $SUCCESS_COUNT"

if [[ ${#FAILED_MODELS[@]} -gt 0 ]]; then
    warn "Failed models: ${#FAILED_MODELS[@]}"
    for FAILED in "${FAILED_MODELS[@]}"; do
        echo "  - $FAILED"
    done
    echo ""
    exit 1
else
    info "✓ All models warmed successfully!"
    echo ""
    exit 0
fi
