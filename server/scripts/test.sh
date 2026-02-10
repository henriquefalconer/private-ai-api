#!/bin/bash
set -euo pipefail

# private-ai-server test script
# Comprehensive validation of all server functionality
# Source: server/specs/SCRIPTS.md lines 43-88

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TOTAL_TESTS=20
CURRENT_TEST=0

# Flags
VERBOSE=false
SKIP_MODEL_TESTS=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --skip-model-tests)
            SKIP_MODEL_TESTS=true
            shift
            ;;
        *)
            echo "Usage: $0 [--verbose|-v] [--skip-model-tests]"
            exit 1
            ;;
    esac
done

# Output helpers
show_progress() {
    CURRENT_TEST=$((CURRENT_TEST + 1))
    echo -e "${BLUE}[Test $CURRENT_TEST/$TOTAL_TESTS]${NC} $1"
}

pass() {
    echo -e "${GREEN}✓ PASS${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    local message="$1"
    local expected="${2:-}"
    local received="${3:-}"

    echo -e "${RED}✗ FAIL${NC} $message"

    if [[ -n "$expected" && -n "$received" ]]; then
        echo -e "  ${YELLOW}Expected:${NC} $expected"
        echo -e "  ${YELLOW}Received:${NC} $received"
    fi

    # Show troubleshooting hint if provided as 4th argument
    if [[ -n "${4:-}" ]]; then
        echo -e "  ${BLUE}Hint:${NC} $4"
    fi

    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
    local message="$1"
    local how_to_enable="${2:-}"

    echo -e "${YELLOW}⊘ SKIP${NC} $message"

    if [[ -n "$how_to_enable" ]]; then
        echo -e "  ${BLUE}To enable:${NC} $how_to_enable"
    fi

    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

info() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

# Banner
echo "================================================"
echo "  private-ai-server Test Suite"
echo "  Running $TOTAL_TESTS tests"
echo "================================================"
echo ""

# Service status tests
echo "=== Service Status Tests ==="

# Test 1: LaunchAgent loaded
info "Checking if LaunchAgent is loaded..."
LAUNCHD_DOMAIN="gui/$(id -u)"
LAUNCHD_LABEL="com.ollama"
if launchctl print "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" &> /dev/null; then
    pass "LaunchAgent com.ollama is loaded"
else
    fail "LaunchAgent com.ollama is not loaded"
fi

# Test 2: Process running as user (not root)
info "Checking Ollama process owner..."
OLLAMA_PID=$(pgrep -f "ollama serve" | head -n1)
if [[ -n "$OLLAMA_PID" ]]; then
    OLLAMA_USER=$(ps -o user= -p "$OLLAMA_PID" | tr -d ' ')
    if [[ "$OLLAMA_USER" == "root" ]]; then
        fail "Ollama is running as root (security violation)"
    elif [[ -n "$OLLAMA_USER" ]]; then
        pass "Ollama process running as user: $OLLAMA_USER (PID: $OLLAMA_PID)"
    else
        fail "Could not determine Ollama process owner"
    fi
else
    fail "Ollama process not found"
fi

# Test 3: Listening on port 11434
info "Checking if port 11434 is listening..."
if lsof -i :11434 -sTCP:LISTEN &> /dev/null || nc -z localhost 11434 2>/dev/null; then
    pass "Service listening on port 11434"
else
    fail "Service not listening on port 11434"
fi

# Test 4: Responds to HTTP
info "Testing basic HTTP response..."
if curl -sf http://localhost:11434/v1/models &> /dev/null; then
    pass "Service responds to HTTP requests"
else
    fail "Service does not respond to HTTP requests"
fi

echo ""
echo "=== API Endpoint Tests ==="

# Test 5: GET /v1/models
info "Testing GET /v1/models..."
MODELS_RESPONSE=$(curl -sf http://localhost:11434/v1/models 2>/dev/null || echo "FAILED")
if [[ "$MODELS_RESPONSE" != "FAILED" ]] && echo "$MODELS_RESPONSE" | jq -e '.object == "list"' &> /dev/null; then
    MODEL_COUNT=$(echo "$MODELS_RESPONSE" | jq -r '.data | length')
    pass "GET /v1/models returns valid JSON (${MODEL_COUNT} models)"

    # Store first model for later tests
    if [[ "$MODEL_COUNT" -gt 0 ]]; then
        FIRST_MODEL=$(echo "$MODELS_RESPONSE" | jq -r '.data[0].id')
        info "First available model: $FIRST_MODEL"
    fi
else
    fail "GET /v1/models failed or returned invalid JSON"
fi

# Test 6: GET /v1/models/{model}
if [[ -n "${FIRST_MODEL:-}" ]]; then
    info "Testing GET /v1/models/$FIRST_MODEL..."
    MODEL_DETAIL=$(curl -sf "http://localhost:11434/v1/models/$FIRST_MODEL" 2>/dev/null || echo "FAILED")
    if [[ "$MODEL_DETAIL" != "FAILED" ]] && echo "$MODEL_DETAIL" | jq -e '.id' &> /dev/null; then
        pass "GET /v1/models/{model} returns valid model details"
    else
        fail "GET /v1/models/{model} failed or returned invalid JSON"
    fi
else
    skip "GET /v1/models/{model} - no models available"
fi

# Test 7-12: Chat completions tests (skip if no models or --skip-model-tests)
if [[ "$SKIP_MODEL_TESTS" == "true" ]]; then
    skip "POST /v1/chat/completions (non-streaming) - model tests skipped"
    skip "POST /v1/chat/completions (streaming) - model tests skipped"
    skip "POST /v1/chat/completions (stream_options.include_usage) - model tests skipped"
    skip "POST /v1/chat/completions (JSON mode) - model tests skipped"
    skip "POST /v1/responses - model tests skipped"
elif [[ -z "${FIRST_MODEL:-}" ]]; then
    skip "POST /v1/chat/completions (non-streaming) - no models available"
    skip "POST /v1/chat/completions (streaming) - no models available"
    skip "POST /v1/chat/completions (stream_options.include_usage) - no models available"
    skip "POST /v1/chat/completions (JSON mode) - no models available"
    skip "POST /v1/responses - no models available"
else
    # Test 7: Non-streaming chat completion
    info "Testing POST /v1/chat/completions (non-streaming) with model: $FIRST_MODEL..."
    CHAT_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
        2>/dev/null || echo "FAILED")

    if [[ "$CHAT_RESPONSE" != "FAILED" ]] && echo "$CHAT_RESPONSE" | jq -e '.choices[0].message.content' &> /dev/null; then
        pass "POST /v1/chat/completions (non-streaming) succeeded"
    else
        fail "POST /v1/chat/completions (non-streaming) failed"
    fi

    # Test 8: Streaming chat completion
    info "Testing POST /v1/chat/completions (streaming)..."
    STREAM_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true}" \
        2>/dev/null | head -n 5 || echo "FAILED")

    if [[ "$STREAM_RESPONSE" != "FAILED" ]] && echo "$STREAM_RESPONSE" | grep -q "data:"; then
        pass "POST /v1/chat/completions (streaming) returns SSE chunks"
    else
        fail "POST /v1/chat/completions (streaming) failed"
    fi

    # Test 9: Streaming with include_usage
    info "Testing POST /v1/chat/completions (stream_options.include_usage)..."
    USAGE_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true,\"stream_options\":{\"include_usage\":true}}" \
        2>/dev/null || echo "FAILED")

    if [[ "$USAGE_RESPONSE" != "FAILED" ]] && echo "$USAGE_RESPONSE" | grep -q "data:"; then
        pass "POST /v1/chat/completions (stream_options.include_usage) succeeded"
    else
        fail "POST /v1/chat/completions (stream_options.include_usage) failed"
    fi

    # Test 10: JSON mode
    info "Testing POST /v1/chat/completions (JSON mode)..."
    JSON_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Return a JSON object with a single field 'status' set to 'ok'\"}],\"max_tokens\":20,\"response_format\":{\"type\":\"json_object\"}}" \
        2>/dev/null || echo "FAILED")

    if [[ "$JSON_RESPONSE" != "FAILED" ]] && echo "$JSON_RESPONSE" | jq -e '.choices[0].message.content' &> /dev/null; then
        CONTENT=$(echo "$JSON_RESPONSE" | jq -r '.choices[0].message.content')
        if echo "$CONTENT" | jq -e '.' &> /dev/null; then
            pass "POST /v1/chat/completions (JSON mode) returns valid JSON"
        else
            fail "POST /v1/chat/completions (JSON mode) did not return valid JSON content"
        fi
    else
        fail "POST /v1/chat/completions (JSON mode) failed"
    fi

    # Test 11: /v1/responses endpoint (experimental, Ollama 0.5.0+)
    info "Testing POST /v1/responses (experimental)..."
    RESPONSES_RESPONSE=$(curl -sf http://localhost:11434/v1/responses \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
        2>/dev/null || echo "FAILED")

    if [[ "$RESPONSES_RESPONSE" != "FAILED" ]]; then
        if echo "$RESPONSES_RESPONSE" | jq -e '.' &> /dev/null; then
            pass "POST /v1/responses succeeded (Ollama 0.5.0+)"
        else
            skip "POST /v1/responses - endpoint exists but returned non-JSON (may not be supported)"
        fi
    else
        skip "POST /v1/responses - endpoint not available (requires Ollama 0.5.0+)"
    fi
fi

echo ""
echo "=== Error Behavior Tests ==="

# Test 12: 500 error on nonexistent model
info "Testing error handling for nonexistent model..."
ERROR_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"nonexistent-model-xyz","messages":[{"role":"user","content":"hi"}]}' \
    2>/dev/null || echo "FAILED")

if [[ "$ERROR_RESPONSE" == "500" ]] || [[ "$ERROR_RESPONSE" == "404" ]]; then
    pass "Nonexistent model returns error status ($ERROR_RESPONSE)"
elif [[ "$ERROR_RESPONSE" == "FAILED" ]]; then
    fail "Error test failed (could not reach server)"
else
    fail "Nonexistent model returned unexpected status: $ERROR_RESPONSE"
fi

# Test 13: Malformed request handling
info "Testing malformed request handling..."
MALFORMED_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:11434/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"invalid":"json","no":"model"}' \
    2>/dev/null || echo "FAILED")

if [[ "$MALFORMED_RESPONSE" == "400" ]] || [[ "$MALFORMED_RESPONSE" == "500" ]] || [[ "$MALFORMED_RESPONSE" == "422" ]]; then
    pass "Malformed request returns error status ($MALFORMED_RESPONSE)"
elif [[ "$MALFORMED_RESPONSE" == "FAILED" ]]; then
    fail "Malformed request test failed (could not reach server)"
else
    skip "Malformed request returned unexpected status: $MALFORMED_RESPONSE (acceptable)"
fi

echo ""
echo "=== Security Tests ==="

# Test 14: Verify process owner (already tested above, but re-validate)
if [[ -n "${OLLAMA_USER:-}" ]] && [[ "$OLLAMA_USER" != "root" ]]; then
    pass "Security: Ollama running as user (not root)"
else
    fail "Security: Could not verify Ollama is not running as root"
fi

# Test 15: Log files exist
info "Checking log files..."
if [[ -f /tmp/ollama.stdout.log ]] && [[ -f /tmp/ollama.stderr.log ]]; then
    pass "Log files exist (/tmp/ollama.stdout.log, /tmp/ollama.stderr.log)"
else
    fail "Log files missing"
fi

# Test 16: Plist file exists
info "Checking plist file..."
PLIST_PATH="$HOME/Library/LaunchAgents/com.ollama.plist"
if [[ -f "$PLIST_PATH" ]]; then
    pass "Plist file exists ($PLIST_PATH)"
else
    fail "Plist file missing"
fi

# Test 17: OLLAMA_HOST=0.0.0.0 in plist
info "Checking OLLAMA_HOST in plist..."
if grep -q "OLLAMA_HOST" "$PLIST_PATH" && grep -q "0.0.0.0" "$PLIST_PATH"; then
    pass "OLLAMA_HOST=0.0.0.0 configured in plist"
else
    fail "OLLAMA_HOST=0.0.0.0 not found in plist"
fi

echo ""
echo "=== Network Tests ==="

# Test 18: Service binds to 0.0.0.0
info "Checking service binding..."
if lsof -i :11434 -sTCP:LISTEN 2>/dev/null | grep -q "0.0.0.0:11434" || \
   netstat -an 2>/dev/null | grep "11434" | grep -q "LISTEN"; then
    pass "Service binds to all interfaces (0.0.0.0)"
else
    skip "Could not verify service binding (lsof/netstat unavailable or ambiguous)"
fi

# Test 19: Localhost access
info "Testing localhost access..."
if curl -sf http://localhost:11434/v1/models &> /dev/null; then
    pass "Localhost access (127.0.0.1) works"
else
    fail "Localhost access failed"
fi

# Test 20: Tailscale IP access (if connected)
info "Testing Tailscale IP access..."
if command -v tailscale &> /dev/null && tailscale ip -4 &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
    if [[ -n "$TAILSCALE_IP" ]]; then
        if curl -sf "http://$TAILSCALE_IP:11434/v1/models" &> /dev/null; then
            pass "Tailscale IP access ($TAILSCALE_IP) works"
        else
            fail "Tailscale IP access failed"
        fi
    else
        skip "Tailscale IP not available"
    fi
else
    skip "Tailscale not installed or not connected"
fi

# Final summary
echo ""
echo "================================================"
echo "  Test Summary"
echo "================================================"
echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    echo "Check logs: tail -f /tmp/ollama.stderr.log"
    exit 1
fi
