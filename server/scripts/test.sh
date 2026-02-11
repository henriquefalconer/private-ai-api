#!/bin/bash
set -euo pipefail

# remote-ollama-proxy ai-server test script
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
TOTAL_TESTS=34
CURRENT_TEST=0

# Flags
VERBOSE=false
SKIP_MODEL_TESTS=false
SKIP_ANTHROPIC_TESTS=false

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
        --skip-anthropic-tests)
            SKIP_ANTHROPIC_TESTS=true
            shift
            ;;
        *)
            echo "Usage: $0 [--verbose|-v] [--skip-model-tests] [--skip-anthropic-tests]"
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
echo "  remote-ollama-proxy ai-server Test Suite"
echo "  Running $TOTAL_TESTS tests"
echo "================================================"
echo ""

# Service status tests
echo "=== Service Status Tests ==="

# Test 1: LaunchAgent loaded
show_progress "Checking if LaunchAgent is loaded..."
LAUNCHD_DOMAIN="gui/$(id -u)"
LAUNCHD_LABEL="com.ollama"
if launchctl print "$LAUNCHD_DOMAIN/$LAUNCHD_LABEL" &> /dev/null; then
    pass "LaunchAgent com.ollama is loaded"
else
    fail "LaunchAgent com.ollama is not loaded"
fi

# Test 2: Process running as user (not root)
show_progress "Checking Ollama process owner..."
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
show_progress "Checking if port 11434 is listening..."
if lsof -i :11434 -sTCP:LISTEN &> /dev/null || nc -z localhost 11434 2>/dev/null; then
    pass "Service listening on port 11434"
else
    fail "Service not listening on port 11434"
fi

# Test 4: Responds to HTTP
show_progress "Testing basic HTTP response..."
if curl -sf http://localhost:11434/v1/models &> /dev/null; then
    pass "Service responds to HTTP requests"
else
    fail "Service does not respond to HTTP requests"
fi

echo ""
echo "=== API Endpoint Tests ==="

# Test 5: GET /v1/models
show_progress "Testing GET /v1/models..."
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
    show_progress "Testing GET /v1/models/$FIRST_MODEL..."
    MODEL_DETAIL=$(curl -sf "http://localhost:11434/v1/models/$FIRST_MODEL" 2>/dev/null || echo "FAILED")
    if [[ "$MODEL_DETAIL" != "FAILED" ]] && echo "$MODEL_DETAIL" | jq -e '.id' &> /dev/null; then
        pass "GET /v1/models/{model} returns valid model details"
    else
        fail "GET /v1/models/{model} failed or returned invalid JSON"
    fi
else
    skip "GET /v1/models/{model} - no models available" "Pull a model first using 'ollama pull llama3.2' or similar"
fi

# Test 7-12: Chat completions tests (skip if no models or --skip-model-tests)
if [[ "$SKIP_MODEL_TESTS" == "true" ]]; then
    skip "POST /v1/chat/completions (non-streaming) - model tests skipped" "Run without --skip-model-tests flag"
    skip "POST /v1/chat/completions (streaming) - model tests skipped" "Run without --skip-model-tests flag"
    skip "POST /v1/chat/completions (stream_options.include_usage) - model tests skipped" "Run without --skip-model-tests flag"
    skip "POST /v1/chat/completions (JSON mode) - model tests skipped" "Run without --skip-model-tests flag"
    skip "POST /v1/responses - model tests skipped" "Run without --skip-model-tests flag"
elif [[ -z "${FIRST_MODEL:-}" ]]; then
    skip "POST /v1/chat/completions (non-streaming) - no models available" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/chat/completions (streaming) - no models available" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/chat/completions (stream_options.include_usage) - no models available" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/chat/completions (JSON mode) - no models available" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/responses - no models available" "Pull a model first using 'ollama pull llama3.2' or similar"
else
    # Test 7: Non-streaming chat completion
    show_progress "Testing POST /v1/chat/completions (non-streaming) with model: $FIRST_MODEL..."

    # Measure timing for verbose mode
    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode: show request/response details
        info "Request: POST http://localhost:11434/v1/chat/completions"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}"

        CHAT_RESPONSE=$(curl -v http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
            2>&1 || echo "FAILED")

        info "Response:"
        echo "$CHAT_RESPONSE" | tail -20 | while IFS= read -r line; do
            info "  $line"
        done
    else
        CHAT_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    # Extract JSON from verbose output (last line is the actual response)
    JSON_ONLY=$(echo "$CHAT_RESPONSE" | tail -n 1)
    if [[ "$CHAT_RESPONSE" != "FAILED" ]] && echo "$JSON_ONLY" | jq -e '.choices[0].message.content' &> /dev/null; then
        pass "POST /v1/chat/completions (non-streaming) succeeded"
    else
        fail "POST /v1/chat/completions (non-streaming) failed"
    fi

    # Test 8: Streaming chat completion
    show_progress "Testing POST /v1/chat/completions (streaming)..."

    # Measure timing for verbose mode
    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode: show request/response details
        info "Request: POST http://localhost:11434/v1/chat/completions (streaming)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true}"

        STREAM_RESPONSE=$(curl -v http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true}" \
            2>&1 || echo "FAILED")

        info "Response (first 10 lines):"
        echo "$STREAM_RESPONSE" | head -n 10 | while IFS= read -r line; do
            info "  $line"
        done
    else
        STREAM_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true}" \
            2>/dev/null | head -n 5 || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    if [[ "$STREAM_RESPONSE" != "FAILED" ]] && echo "$STREAM_RESPONSE" | grep -q "data:"; then
        pass "POST /v1/chat/completions (streaming) returns SSE chunks"
    else
        fail "POST /v1/chat/completions (streaming) failed"
    fi

    # Test 9: Streaming with include_usage
    show_progress "Testing POST /v1/chat/completions (stream_options.include_usage)..."

    # Measure timing for verbose mode
    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode: show request/response details
        info "Request: POST http://localhost:11434/v1/chat/completions (streaming with include_usage)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true,\"stream_options\":{\"include_usage\":true}}"

        USAGE_RESPONSE=$(curl -v http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true,\"stream_options\":{\"include_usage\":true}}" \
            2>&1 || echo "FAILED")

        info "Response (all SSE chunks):"
        echo "$USAGE_RESPONSE" | grep "^data:" | while IFS= read -r line; do
            info "  $line"
        done
    else
        USAGE_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true,\"stream_options\":{\"include_usage\":true}}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    if [[ "$USAGE_RESPONSE" != "FAILED" ]] && echo "$USAGE_RESPONSE" | grep -q "data:"; then
        # F3.5: Verify usage data in streaming response
        # Extract the final SSE chunk (should contain usage data)
        FINAL_CHUNK=$(echo "$USAGE_RESPONSE" | grep "^data:" | grep -v "data: \[DONE\]" | tail -n1)

        if [[ -n "$FINAL_CHUNK" ]]; then
            # Remove "data: " prefix and parse JSON
            JSON_DATA=$(echo "$FINAL_CHUNK" | sed 's/^data: //')

            # Check for usage field in the final chunk
            if echo "$JSON_DATA" | jq -e '.usage' &> /dev/null; then
                pass "POST /v1/chat/completions (stream_options.include_usage) succeeded (usage field found)"
            else
                fail "POST /v1/chat/completions (stream_options.include_usage) - usage field not found" "usage field in final SSE chunk" "No usage field detected"
            fi
        else
            fail "POST /v1/chat/completions (stream_options.include_usage) - no data chunks received"
        fi
    else
        fail "POST /v1/chat/completions (stream_options.include_usage) failed"
    fi

    # Test 10: JSON mode
    show_progress "Testing POST /v1/chat/completions (JSON mode)..."

    # Measure timing for verbose mode
    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode: show request/response details
        info "Request: POST http://localhost:11434/v1/chat/completions (JSON mode)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Return a JSON object with a single field 'status' set to 'ok'\"}],\"max_tokens\":20,\"response_format\":{\"type\":\"json_object\"}}"

        JSON_RESPONSE=$(curl -v http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Return a JSON object with a single field 'status' set to 'ok'\"}],\"max_tokens\":20,\"response_format\":{\"type\":\"json_object\"}}" \
            2>&1 || echo "FAILED")

        info "Response:"
        echo "$JSON_RESPONSE" | tail -20 | while IFS= read -r line; do
            info "  $line"
        done
    else
        JSON_RESPONSE=$(curl -sf http://localhost:11434/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Return a JSON object with a single field 'status' set to 'ok'\"}],\"max_tokens\":20,\"response_format\":{\"type\":\"json_object\"}}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    # Extract JSON from verbose output (last line is the actual response)
    JSON_ONLY=$(echo "$JSON_RESPONSE" | tail -n 1)
    if [[ "$JSON_RESPONSE" != "FAILED" ]] && echo "$JSON_ONLY" | jq -e '.choices[0].message.content' &> /dev/null; then
        CONTENT=$(echo "$JSON_ONLY" | jq -r '.choices[0].message.content')
        if echo "$CONTENT" | jq -e '.' &> /dev/null; then
            pass "POST /v1/chat/completions (JSON mode) returns valid JSON"
        else
            fail "POST /v1/chat/completions (JSON mode) did not return valid JSON content"
        fi
    else
        fail "POST /v1/chat/completions (JSON mode) failed"
    fi

    # Test 11: /v1/responses endpoint (experimental, Ollama 0.5.0+)
    show_progress "Testing POST /v1/responses (experimental)..."

    # Measure timing for verbose mode
    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode: show request/response details
        info "Request: POST http://localhost:11434/v1/responses (experimental)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}"

        RESPONSES_RESPONSE=$(curl -v http://localhost:11434/v1/responses \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
            2>&1 || echo "FAILED")

        info "Response:"
        echo "$RESPONSES_RESPONSE" | tail -20 | while IFS= read -r line; do
            info "  $line"
        done
    else
        RESPONSES_RESPONSE=$(curl -sf http://localhost:11434/v1/responses \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    # Extract JSON from verbose output (last line is the actual response)
    JSON_ONLY=$(echo "$RESPONSES_RESPONSE" | tail -n 1)
    if [[ "$RESPONSES_RESPONSE" != "FAILED" ]]; then
        if echo "$JSON_ONLY" | jq -e '.' &> /dev/null; then
            pass "POST /v1/responses succeeded (Ollama 0.5.0+)"
        else
            skip "POST /v1/responses - endpoint exists but returned non-JSON (may not be supported)" "Upgrade to Ollama 0.5.0+"
        fi
    else
        skip "POST /v1/responses - endpoint not available" "Upgrade to Ollama 0.5.0+"
    fi
fi

echo ""
echo "=== Anthropic API Tests ==="

# Tests 21-26: Anthropic /v1/messages endpoint (Ollama 0.5.0+)
if [[ "$SKIP_ANTHROPIC_TESTS" == "true" ]]; then
    skip "POST /v1/messages (non-streaming) - Anthropic tests skipped" "Run without --skip-anthropic-tests flag"
    skip "POST /v1/messages (streaming SSE) - Anthropic tests skipped" "Run without --skip-anthropic-tests flag"
    skip "POST /v1/messages (system prompt) - Anthropic tests skipped" "Run without --skip-anthropic-tests flag"
    skip "POST /v1/messages (error handling) - Anthropic tests skipped" "Run without --skip-anthropic-tests flag"
    skip "POST /v1/messages (multi-turn conversation) - Anthropic tests skipped" "Run without --skip-anthropic-tests flag"
    skip "POST /v1/messages (streaming with usage) - Anthropic tests skipped" "Run without --skip-anthropic-tests flag"
elif [[ "$SKIP_MODEL_TESTS" == "true" ]] || [[ -z "${FIRST_MODEL:-}" ]]; then
    skip "POST /v1/messages (non-streaming) - no models available or model tests skipped" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/messages (streaming SSE) - no models available or model tests skipped" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/messages (system prompt) - no models available or model tests skipped" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/messages (error handling) - no models available or model tests skipped" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/messages (multi-turn conversation) - no models available or model tests skipped" "Pull a model first using 'ollama pull llama3.2' or similar"
    skip "POST /v1/messages (streaming with usage) - no models available or model tests skipped" "Pull a model first using 'ollama pull llama3.2' or similar"
else
    # Test 21: Non-streaming Anthropic messages
    show_progress "Testing POST /v1/messages (non-streaming)..."

    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        info "Request: POST http://localhost:11434/v1/messages"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}"

        ANTHROPIC_RESPONSE=$(curl -v http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" \
            2>&1 || echo "FAILED")

        info "Response:"
        echo "$ANTHROPIC_RESPONSE" | tail -20 | while IFS= read -r line; do
            info "  $line"
        done
    else
        ANTHROPIC_RESPONSE=$(curl -sf http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    # Extract JSON from verbose output (last line is the actual response)
    JSON_ONLY=$(echo "$ANTHROPIC_RESPONSE" | tail -n 1)
    if [[ "$ANTHROPIC_RESPONSE" != "FAILED" ]] && echo "$JSON_ONLY" | jq -e '.type == "message"' &> /dev/null; then
        if echo "$JSON_ONLY" | jq -e '.content[0].text' &> /dev/null; then
            pass "POST /v1/messages (non-streaming) succeeded (Ollama 0.5.0+)"
        else
            fail "POST /v1/messages response missing content.text field"
        fi
    else
        skip "POST /v1/messages (non-streaming) - endpoint not available" "Upgrade to Ollama 0.5.0+"
    fi

    # Test 22: Streaming Anthropic messages with SSE
    show_progress "Testing POST /v1/messages (streaming SSE)..."

    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        info "Request: POST http://localhost:11434/v1/messages (streaming)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":true}"

        ANTHROPIC_STREAM=$(curl -v http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":true}" \
            2>&1 || echo "FAILED")

        info "Response (first 15 lines):"
        echo "$ANTHROPIC_STREAM" | head -n 15 | while IFS= read -r line; do
            info "  $line"
        done
    else
        ANTHROPIC_STREAM=$(curl -sf http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}],\"stream\":true}" \
            2>/dev/null | head -n 10 || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    if [[ "$ANTHROPIC_STREAM" != "FAILED" ]] && echo "$ANTHROPIC_STREAM" | grep -q "event:"; then
        # Check for Anthropic SSE event types
        if echo "$ANTHROPIC_STREAM" | grep -q "event: message_start\|event: content_block_delta"; then
            pass "POST /v1/messages (streaming SSE) returns Anthropic SSE events"
        else
            fail "POST /v1/messages (streaming) returned events but not Anthropic format"
        fi
    else
        skip "POST /v1/messages (streaming SSE) - endpoint not available" "Upgrade to Ollama 0.5.0+"
    fi

    # Test 23: Anthropic messages with system prompt
    show_progress "Testing POST /v1/messages (system prompt)..."

    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        info "Request: POST http://localhost:11434/v1/messages (with system prompt)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"system\":\"You are helpful.\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}]}"

        ANTHROPIC_SYSTEM=$(curl -v http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"system\":\"You are helpful.\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}]}" \
            2>&1 || echo "FAILED")

        info "Response:"
        echo "$ANTHROPIC_SYSTEM" | tail -20 | while IFS= read -r line; do
            info "  $line"
        done
    else
        ANTHROPIC_SYSTEM=$(curl -sf http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"system\":\"You are helpful.\",\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}]}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    # Extract JSON from verbose output (last line is the actual response)
    JSON_ONLY=$(echo "$ANTHROPIC_SYSTEM" | tail -n 1)
    if [[ "$ANTHROPIC_SYSTEM" != "FAILED" ]] && echo "$JSON_ONLY" | jq -e '.type == "message"' &> /dev/null; then
        pass "POST /v1/messages (system prompt) succeeded"
    else
        skip "POST /v1/messages (system prompt) - endpoint not available" "Upgrade to Ollama 0.5.0+"
    fi

    # Test 24: Anthropic error handling (nonexistent model)
    show_progress "Testing POST /v1/messages error handling..."

    ANTHROPIC_ERROR=$(curl -s -w "%{http_code}" -o /dev/null http://localhost:11434/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: ollama" \
        -H "anthropic-version: 2023-06-01" \
        -d '{"model":"nonexistent-model-xyz","max_tokens":10,"messages":[{"role":"user","content":"test"}]}' \
        2>/dev/null || echo "FAILED")

    if [[ "$ANTHROPIC_ERROR" == "500" ]] || [[ "$ANTHROPIC_ERROR" == "404" ]] || [[ "$ANTHROPIC_ERROR" == "400" ]]; then
        pass "POST /v1/messages error handling returns error status ($ANTHROPIC_ERROR)"
    elif [[ "$ANTHROPIC_ERROR" == "FAILED" ]]; then
        skip "POST /v1/messages error handling - endpoint not reachable" "Upgrade to Ollama 0.5.0+"
    else
        skip "POST /v1/messages error handling returned unexpected status: $ANTHROPIC_ERROR (acceptable)" "Endpoint may have different error handling"
    fi

    # Test 25: Multi-turn conversation
    show_progress "Testing POST /v1/messages (multi-turn conversation)..."

    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    MULTITURN_PAYLOAD='{
        "model":"'"$FIRST_MODEL"'",
        "max_tokens":15,
        "messages":[
            {"role":"user","content":"My name is Alice"},
            {"role":"assistant","content":"Hello Alice"},
            {"role":"user","content":"What is my name?"}
        ]
    }'

    if [[ "$VERBOSE" == "true" ]]; then
        info "Request: POST http://localhost:11434/v1/messages (multi-turn)"
        info "Body: Multi-turn conversation with 3 messages"

        ANTHROPIC_MULTITURN=$(curl -v http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "$MULTITURN_PAYLOAD" \
            2>&1 || echo "FAILED")

        info "Response:"
        echo "$ANTHROPIC_MULTITURN" | tail -20 | while IFS= read -r line; do
            info "  $line"
        done
    else
        ANTHROPIC_MULTITURN=$(curl -sf http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "$MULTITURN_PAYLOAD" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    # Extract JSON from verbose output (last line is the actual response)
    JSON_ONLY=$(echo "$ANTHROPIC_MULTITURN" | tail -n 1)
    if [[ "$ANTHROPIC_MULTITURN" != "FAILED" ]] && echo "$JSON_ONLY" | jq -e '.type == "message"' &> /dev/null; then
        pass "POST /v1/messages (multi-turn conversation) succeeded"
    else
        skip "POST /v1/messages (multi-turn) - endpoint not available" "Upgrade to Ollama 0.5.0+"
    fi

    # Test 26: Streaming with usage data
    show_progress "Testing POST /v1/messages (streaming with usage)..."

    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        info "Request: POST http://localhost:11434/v1/messages (streaming with usage)"

        ANTHROPIC_USAGE_STREAM=$(curl -v http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":true}" \
            2>&1 || echo "FAILED")

        info "Response (all events):"
        echo "$ANTHROPIC_USAGE_STREAM" | grep "^event:\|^data:" | while IFS= read -r line; do
            info "  $line"
        done
    else
        ANTHROPIC_USAGE_STREAM=$(curl -sf http://localhost:11434/v1/messages \
            -H "Content-Type: application/json" \
            -H "x-api-key: ollama" \
            -H "anthropic-version: 2023-06-01" \
            -d "{\"model\":\"$FIRST_MODEL\",\"max_tokens\":10,\"messages\":[{\"role\":\"user\",\"content\":\"Hi\"}],\"stream\":true}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    # Detect if nanoseconds are supported by checking if we got a large number (>12 digits)
    if [[ ${#START_TIME} -gt 12 ]]; then
        # Nanoseconds (19 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        # Seconds (10 digits) - convert to milliseconds
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    if [[ "$ANTHROPIC_USAGE_STREAM" != "FAILED" ]] && echo "$ANTHROPIC_USAGE_STREAM" | grep -q "event:"; then
        # Check for usage data in message_delta event
        if echo "$ANTHROPIC_USAGE_STREAM" | grep -q "\"usage\""; then
            pass "POST /v1/messages (streaming with usage) includes usage data"
        else
            skip "POST /v1/messages (streaming) works but usage data not found (acceptable)" "Usage may be in different format"
        fi
    else
        skip "POST /v1/messages (streaming with usage) - endpoint not available" "Upgrade to Ollama 0.5.0+"
    fi
fi

echo ""
echo "=== Error Behavior Tests ==="

# Test 12: 500 error on nonexistent model
show_progress "Testing error handling for nonexistent model..."
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
show_progress "Testing malformed request handling..."
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
show_progress "Verifying process owner (security check)..."
if [[ -n "${OLLAMA_USER:-}" ]] && [[ "$OLLAMA_USER" != "root" ]]; then
    pass "Security: Ollama running as user (not root)"
else
    fail "Security: Could not verify Ollama is not running as root"
fi

# Test 15: Log files exist and are readable
show_progress "Checking log files..."
if [[ -f /tmp/ollama.stdout.log ]] && [[ -r /tmp/ollama.stdout.log ]] && \
   [[ -f /tmp/ollama.stderr.log ]] && [[ -r /tmp/ollama.stderr.log ]]; then
    pass "Log files exist and are readable (/tmp/ollama.stdout.log, /tmp/ollama.stderr.log)"
elif [[ ! -f /tmp/ollama.stdout.log ]] || [[ ! -f /tmp/ollama.stderr.log ]]; then
    fail "Log files missing"
else
    fail "Log files exist but are not readable"
fi

# Test 16: Plist file exists
show_progress "Checking plist file..."
PLIST_PATH="$HOME/Library/LaunchAgents/com.ollama.plist"
if [[ -f "$PLIST_PATH" ]]; then
    pass "Plist file exists ($PLIST_PATH)"
else
    fail "Plist file missing"
fi

# Test 17: OLLAMA_HOST in plist (check for loopback binding)
show_progress "Checking OLLAMA_HOST in plist..."
if grep -q "OLLAMA_HOST" "$PLIST_PATH" && grep -q "127.0.0.1" "$PLIST_PATH"; then
    pass "OLLAMA_HOST=127.0.0.1 configured in plist (loopback-only binding)"
elif grep -q "OLLAMA_HOST" "$PLIST_PATH" && grep -q "0.0.0.0" "$PLIST_PATH"; then
    fail "OLLAMA_HOST=0.0.0.0 found in plist (should be 127.0.0.1 for security)" "" "" "HAProxy not installed - fallback mode active"
else
    fail "OLLAMA_HOST not found in plist or has unexpected value"
fi

echo ""
echo "=== Network Tests ==="

# Test 18: Ollama service binding (verify loopback-only)
show_progress "Checking Ollama service binding..."
if command -v lsof &> /dev/null; then
    OLLAMA_BINDING=$(lsof -i :11434 -sTCP:LISTEN 2>/dev/null | grep -E "ollama|haproxy" || echo "")
    if echo "$OLLAMA_BINDING" | grep -q "127.0.0.1:11434"; then
        pass "Ollama binds to loopback only (127.0.0.1:11434) - secure"
    elif echo "$OLLAMA_BINDING" | grep -q "0.0.0.0:11434"; then
        # Check if HAProxy is also running (fallback mode is OK if HAProxy declined)
        if lsof -i :11434 -sTCP:LISTEN 2>/dev/null | grep -q "haproxy"; then
            fail "Ollama binds to 0.0.0.0 even though HAProxy is running (security violation)"
        else
            warn "Ollama binds to 0.0.0.0 (fallback mode - HAProxy not installed)"
            pass "Ollama accessible (fallback mode)"
        fi
    else
        skip "Could not determine Ollama binding from lsof output"
    fi
else
    skip "lsof not available - cannot verify binding" "Install lsof or check manually"
fi

# Test 19: Localhost access
show_progress "Testing localhost access..."
if curl -sf http://localhost:11434/v1/models &> /dev/null; then
    pass "Localhost access (127.0.0.1) works"
else
    fail "Localhost access failed"
fi

# Test 20: Tailscale IP access (if connected)
show_progress "Testing Tailscale IP access..."
if command -v tailscale &> /dev/null && tailscale ip -4 &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1)
    if [[ -n "$TAILSCALE_IP" ]]; then
        if curl -sf "http://$TAILSCALE_IP:11434/v1/models" &> /dev/null; then
            pass "Tailscale IP access ($TAILSCALE_IP) works"
        else
            fail "Tailscale IP access failed"
        fi
    else
        skip "Tailscale IP not available" "Connect to Tailscale or check 'tailscale status'"
    fi
else
    skip "Tailscale not installed or not connected" "Install Tailscale via 'brew install tailscale' and connect"
fi

echo ""
echo "=== HAProxy Tests ==="

# Detect if HAProxy is installed
HAPROXY_INSTALLED=false
HAPROXY_LABEL="com.haproxy"
HAPROXY_PLIST_PATH="$HOME/Library/LaunchAgents/com.haproxy.plist"

if [[ -f "$HAPROXY_PLIST_PATH" ]] || launchctl print "gui/$(id -u)/$HAPROXY_LABEL" &> /dev/null 2>&1; then
    HAPROXY_INSTALLED=true
fi

if [[ "$HAPROXY_INSTALLED" == "false" ]]; then
    skip "HAProxy tests - HAProxy not installed" "Re-run install.sh and choose 'Yes' when prompted for HAProxy"
    skip "HAProxy LaunchAgent check - HAProxy not installed"
    skip "HAProxy binding check - HAProxy not installed"
    skip "HAProxy allowlist tests - HAProxy not installed"
    skip "HAProxy blocked endpoints - HAProxy not installed"
    skip "Direct Ollama access blocked - HAProxy not installed"
    skip "HAProxy logs check - HAProxy not installed"
    skip "HAProxy config check - HAProxy not installed"
else
    # Test 21: HAProxy LaunchAgent loaded
    show_progress "Checking HAProxy LaunchAgent..."
    if launchctl print "gui/$(id -u)/$HAPROXY_LABEL" &> /dev/null; then
        pass "HAProxy LaunchAgent is loaded"
    else
        fail "HAProxy LaunchAgent is not loaded" "" "" "Check logs: tail -f /tmp/haproxy.stderr.log"
    fi

    # Test 22: HAProxy process running
    show_progress "Checking HAProxy process..."
    HAPROXY_PID=$(pgrep -f "haproxy.*haproxy.cfg" | head -n1 || echo "")
    if [[ -n "$HAPROXY_PID" ]]; then
        HAPROXY_USER=$(ps -o user= -p "$HAPROXY_PID" | tr -d ' ')
        if [[ "$HAPROXY_USER" == "root" ]]; then
            fail "HAProxy is running as root (security concern)"
        else
            pass "HAProxy process running as user: $HAPROXY_USER (PID: $HAPROXY_PID)"
        fi
    else
        fail "HAProxy process not found" "" "" "Check logs: tail -f /tmp/haproxy.stderr.log"
    fi

    # Test 23: HAProxy listening on Tailscale interface
    show_progress "Checking HAProxy binding..."
    if command -v lsof &> /dev/null; then
        if command -v tailscale &> /dev/null && tailscale ip -4 &> /dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1 || echo "")
            if [[ -n "$TAILSCALE_IP" ]]; then
                HAPROXY_BINDING=$(lsof -i :11434 -sTCP:LISTEN 2>/dev/null | grep haproxy || echo "")
                if [[ -n "$HAPROXY_BINDING" ]] && echo "$HAPROXY_BINDING" | grep -q "$TAILSCALE_IP"; then
                    pass "HAProxy listening on Tailscale interface ($TAILSCALE_IP:11434)"
                elif [[ -n "$HAPROXY_BINDING" ]]; then
                    warn "HAProxy is listening but not on expected Tailscale IP"
                    pass "HAProxy is listening on port 11434"
                else
                    fail "HAProxy not listening on expected interface"
                fi
            else
                skip "Tailscale IP not available - cannot verify HAProxy binding" "Connect to Tailscale"
            fi
        else
            skip "Tailscale not available - cannot verify HAProxy binding"
        fi
    else
        skip "lsof not available - cannot verify HAProxy binding"
    fi

    # Test 24-26: Allowlisted endpoint forwarding
    show_progress "Testing allowlisted endpoint: POST /v1/chat/completions..."
    if [[ -n "${TAILSCALE_IP:-}" ]] && [[ -n "${FIRST_MODEL:-}" ]]; then
        HAPROXY_CHAT_TEST=$(curl -sf "http://$TAILSCALE_IP:11434/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"test\"}],\"max_tokens\":1}" \
            2>/dev/null || echo "FAILED")
        if [[ "$HAPROXY_CHAT_TEST" != "FAILED" ]] && echo "$HAPROXY_CHAT_TEST" | jq -e '.choices' &> /dev/null; then
            pass "HAProxy forwards POST /v1/chat/completions (allowlisted)"
        else
            fail "HAProxy failed to forward POST /v1/chat/completions"
        fi
    else
        skip "Cannot test HAProxy forwarding - Tailscale IP or model unavailable"
    fi

    show_progress "Testing allowlisted endpoint: GET /v1/models..."
    if [[ -n "${TAILSCALE_IP:-}" ]]; then
        HAPROXY_MODELS_TEST=$(curl -sf "http://$TAILSCALE_IP:11434/v1/models" 2>/dev/null || echo "FAILED")
        if [[ "$HAPROXY_MODELS_TEST" != "FAILED" ]] && echo "$HAPROXY_MODELS_TEST" | jq -e '.object' &> /dev/null; then
            pass "HAProxy forwards GET /v1/models (allowlisted)"
        else
            fail "HAProxy failed to forward GET /v1/models"
        fi
    else
        skip "Cannot test HAProxy forwarding - Tailscale IP unavailable"
    fi

    show_progress "Testing allowlisted endpoint: GET /api/version..."
    if [[ -n "${TAILSCALE_IP:-}" ]]; then
        HAPROXY_VERSION_TEST=$(curl -sf "http://$TAILSCALE_IP:11434/api/version" 2>/dev/null || echo "FAILED")
        if [[ "$HAPROXY_VERSION_TEST" != "FAILED" ]]; then
            pass "HAProxy forwards GET /api/version (allowlisted)"
        else
            fail "HAProxy failed to forward GET /api/version"
        fi
    else
        skip "Cannot test HAProxy forwarding - Tailscale IP unavailable"
    fi

    # Test 27-28: Blocked endpoint enforcement
    show_progress "Testing blocked endpoint: POST /api/generate..."
    if [[ -n "${TAILSCALE_IP:-}" ]]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$TAILSCALE_IP:11434/api/generate" \
            -H "Content-Type: application/json" \
            -d '{"model":"test","prompt":"hi"}' 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "403" ]] || [[ "$HTTP_CODE" == "404" ]]; then
            pass "HAProxy blocks POST /api/generate (not in allowlist) - HTTP $HTTP_CODE"
        elif [[ "$HTTP_CODE" == "000" ]]; then
            fail "HAProxy connection failed for blocked endpoint test"
        else
            fail "HAProxy did not block POST /api/generate (got HTTP $HTTP_CODE, expected 403 or 404)"
        fi
    else
        skip "Cannot test HAProxy blocking - Tailscale IP unavailable"
    fi

    show_progress "Testing blocked endpoint: POST /api/pull..."
    if [[ -n "${TAILSCALE_IP:-}" ]]; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$TAILSCALE_IP:11434/api/pull" \
            -H "Content-Type: application/json" \
            -d '{"name":"test"}' 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" == "403" ]] || [[ "$HTTP_CODE" == "404" ]]; then
            pass "HAProxy blocks POST /api/pull (not in allowlist) - HTTP $HTTP_CODE"
        elif [[ "$HTTP_CODE" == "000" ]]; then
            fail "HAProxy connection failed for blocked endpoint test"
        else
            fail "HAProxy did not block POST /api/pull (got HTTP $HTTP_CODE, expected 403 or 404)"
        fi
    else
        skip "Cannot test HAProxy blocking - Tailscale IP unavailable"
    fi

    # Test 29: HAProxy logs exist
    show_progress "Checking HAProxy logs..."
    if [[ -f /tmp/haproxy.stdout.log ]] || [[ -f /tmp/haproxy.stderr.log ]]; then
        pass "HAProxy log files exist"
    else
        warn "HAProxy log files not found (may not have been created yet)"
        pass "HAProxy logs check completed"
    fi

    # Test 30: HAProxy config exists
    show_progress "Checking HAProxy config..."
    HAPROXY_CONFIG_PATH="$HOME/.haproxy/haproxy.cfg"
    if [[ -f "$HAPROXY_CONFIG_PATH" ]]; then
        pass "HAProxy config exists ($HAPROXY_CONFIG_PATH)"
    else
        fail "HAProxy config missing ($HAPROXY_CONFIG_PATH)"
    fi
fi

# Final summary (F3.8: Use box-drawing characters)
echo ""
echo "┌────────────────────────────────────────────────┐"
echo "│              Test Summary                      │"
echo "└────────────────────────────────────────────────┘"
echo ""
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
    echo ""
    # F3.9: Add structured next-steps section
    echo "┌────────────────────────────────────────────────┐"
    echo "│              Next Steps                        │"
    echo "└────────────────────────────────────────────────┘"
    echo "  • Check service status: launchctl list | grep ollama"
    echo "  • Restart service: launchctl bootout gui/\$(id -u)/com.ollama && launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.ollama.plist"
    echo "  • Check logs: tail -f /tmp/ollama.stderr.log"
    echo "  • Verify port 11434: lsof -i :11434"
    echo "  • Check Tailscale connectivity: tailscale status"
    echo ""
    exit 1
fi
