#!/bin/bash
set -euo pipefail

# Compare analytics between two Ralph loop runs
# Usage: ./compare-analytics.sh <run1_dir> <run2_dir>
# Example: ./compare-analytics.sh analytics/run-20260210-143022 analytics/run-20260210-150015

if [ $# -ne 2 ]; then
    echo "Usage: $0 <run1_dir> <run2_dir>"
    echo ""
    echo "Example:"
    echo "  $0 analytics/run-20260210-143022 analytics/run-20260210-150015"
    echo ""
    echo "Available runs:"
    ls -d analytics/run-* 2>/dev/null | tail -5 || echo "  (no runs found)"
    exit 1
fi

RUN1="$1"
RUN2="$2"

if [ ! -d "$RUN1" ] || [ ! -d "$RUN2" ]; then
    echo "Error: One or both directories not found"
    exit 1
fi

# Color definitions
GREEN_BOLD="\033[1;32m"
YELLOW_BOLD="\033[1;33m"
RED_BOLD="\033[1;31m"
CYAN_BOLD="\033[1;36m"
RESET="\033[0m"

echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN_BOLD}   Analytics Comparison${RESET}"
echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# Extract run metadata
RUN1_NAME=$(basename "$RUN1" | sed 's/run-//')
RUN2_NAME=$(basename "$RUN2" | sed 's/run-//')

echo -e "${CYAN_BOLD}Run 1:${RESET} $RUN1_NAME"
echo -e "${CYAN_BOLD}Run 2:${RESET} $RUN2_NAME"
echo ""

# Function to extract stats from a run
get_stats() {
    local run_dir=$1
    local iter_count=$(ls -1 "$run_dir"/iteration-*.json 2>/dev/null | wc -l | tr -d ' ')

    local total_subagents=0
    local total_reads=0
    local total_edits=0
    local total_cache_creation=0
    local total_cache_reads=0
    local total_output=0

    for iter_log in "$run_dir"/iteration-*.json; do
        if [ -f "$iter_log" ]; then
            local subagents=$(grep -c '"name":"Task"' "$iter_log" 2>/dev/null || echo "0")
            local reads=$(grep -c '"name":"Read"' "$iter_log" 2>/dev/null || echo "0")
            local edits=$(($(grep -c '"name":"Edit"' "$iter_log" 2>/dev/null || echo "0") + $(grep -c '"name":"Write"' "$iter_log" 2>/dev/null || echo "0")))
            local cache_cr=$(grep -o '"cache_creation_input_tokens":[0-9]*' "$iter_log" | awk -F: '{sum+=$2} END {print sum+0}')
            local cache_rd=$(grep -o '"cache_read_input_tokens":[0-9]*' "$iter_log" | awk -F: '{sum+=$2} END {print sum+0}')
            local output=$(grep -o '"output_tokens":[0-9]*' "$iter_log" | awk -F: '{sum+=$2} END {print sum+0}')

            total_subagents=$((total_subagents + subagents))
            total_reads=$((total_reads + reads))
            total_edits=$((total_edits + edits))
            total_cache_creation=$((total_cache_creation + cache_cr))
            total_cache_reads=$((total_cache_reads + cache_rd))
            total_output=$((total_output + output))
        fi
    done

    echo "$iter_count|$total_subagents|$total_reads|$total_edits|$total_cache_creation|$total_cache_reads|$total_output"
}

# Get stats for both runs
STATS1=$(get_stats "$RUN1")
STATS2=$(get_stats "$RUN2")

# Parse stats
IFS='|' read -r ITER1 SUB1 READ1 EDIT1 CACHE_CR1 CACHE_RD1 OUT1 <<< "$STATS1"
IFS='|' read -r ITER2 SUB2 READ2 EDIT2 CACHE_CR2 CACHE_RD2 OUT2 <<< "$STATS2"

# Calculate averages (with zero checks to prevent divide-by-zero)
if [ "$ITER1" -eq 0 ]; then
    AVG_SUB1=0
    AVG_READ1=0
else
    AVG_SUB1=$((SUB1 / ITER1))
    AVG_READ1=$((READ1 / ITER1))
fi

if [ "$ITER2" -eq 0 ]; then
    AVG_SUB2=0
    AVG_READ2=0
else
    AVG_SUB2=$((SUB2 / ITER2))
    AVG_READ2=$((READ2 / ITER2))
fi

# Calculate cache hit rates
if [ $((CACHE_CR1 + CACHE_RD1)) -gt 0 ]; then
    CACHE_RATE1=$((CACHE_RD1 * 100 / (CACHE_CR1 + CACHE_RD1)))
else
    CACHE_RATE1=0
fi

if [ $((CACHE_CR2 + CACHE_RD2)) -gt 0 ]; then
    CACHE_RATE2=$((CACHE_RD2 * 100 / (CACHE_CR2 + CACHE_RD2)))
else
    CACHE_RATE2=0
fi

# Display comparison
printf "%-30s %15s %15s %10s\n" "Metric" "Run 1" "Run 2" "Diff"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

printf "%-30s %15s %15s %10s\n" "Iterations" "$ITER1" "$ITER2" "$((ITER2 - ITER1))"
printf "%-30s %15s %15s %10s\n" "Total subagents" "$SUB1" "$SUB2" "$((SUB2 - SUB1))"
printf "%-30s %15s %15s %10s\n" "Avg subagents/iter" "$AVG_SUB1" "$AVG_SUB2" "$((AVG_SUB2 - AVG_SUB1))"
printf "%-30s %15s %15s %10s\n" "Total reads" "$READ1" "$READ2" "$((READ2 - READ1))"
printf "%-30s %15s %15s %10s\n" "Avg reads/iter" "$AVG_READ1" "$AVG_READ2" "$((AVG_READ2 - AVG_READ1))"
printf "%-30s %15s %15s %10s\n" "Total edits/writes" "$EDIT1" "$EDIT2" "$((EDIT2 - EDIT1))"
printf "%-30s %15s %15s %10s\n" "Cache creation tokens" "$CACHE_CR1" "$CACHE_CR2" "$((CACHE_CR2 - CACHE_CR1))"
printf "%-30s %15s %15s %10s\n" "Cache read tokens" "$CACHE_RD1" "$CACHE_RD2" "$((CACHE_RD2 - CACHE_RD1))"
printf "%-30s %15s %15s %10s\n" "Cache hit rate (%)" "$CACHE_RATE1" "$CACHE_RATE2" "$((CACHE_RATE2 - CACHE_RATE1))"
printf "%-30s %15s %15s %10s\n" "Output tokens" "$OUT1" "$OUT2" "$((OUT2 - OUT1))"

echo ""
echo -e "${GREEN_BOLD}Key Insights:${RESET}"

# Subagent comparison
if [ $AVG_SUB1 -lt 50 ] && [ $AVG_SUB2 -lt 50 ]; then
    echo -e "  ${GREEN_BOLD}✓${RESET} Both runs used modest parallelism (<50 subagents/iter)"
    echo -e "    → Single Ollama server likely sufficient"
fi

# Cache comparison
if [ $CACHE_RATE1 -gt 50 ]; then
    echo -e "  ${YELLOW_BOLD}⚠${RESET} Run 1 benefited significantly from caching (${CACHE_RATE1}%)"
    echo -e "    → Ollama (no caching) would be slower"
fi

# Workload comparison (with zero check)
if [ "$ITER1" -gt 0 ] && [ $((READ1 / ITER1)) -gt $((EDIT1 / ITER1 * 3)) ]; then
    echo -e "  ${GREEN_BOLD}✓${RESET} Workload is read-heavy (${AVG_READ1}:$((EDIT1/ITER1)) read:edit ratio)"
    echo -e "    → Local models suitable for majority of operations"
fi

echo ""
echo -e "${CYAN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN_BOLD}Decision Matrix (Ollama Migration Guidance):${RESET}"
echo -e "${CYAN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
printf "%-18s %-16s %-12s %-14s %-50s\n" "Mode" "Subagents/iter" "Cache hit" "Shallow:Deep" "Recommendation"
echo "─────────────────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-18s %-16s %-12s %-14s %-50s\n" "Plan (Opus)" "Any" ">50%" "Any" "❌ Keep Anthropic cloud (quality critical)"
printf "%-18s %-16s %-12s %-14s %-50s\n" "Build (Sonnet)" "<10" "<30%" ">5:1" "✅ Consider Ollama for simple builds"
printf "%-18s %-16s %-12s %-14s %-50s\n" "Build (Sonnet)" "<20" "30-60%" "3:1-5:1" "⚠️  Test Ollama carefully"
printf "%-18s %-16s %-12s %-14s %-50s\n" "Build (Sonnet)" "<20" ">60%" "<3:1" "❌ Keep Anthropic (cache-dependent)"
printf "%-18s %-16s %-12s %-14s %-50s\n" "Build (Sonnet)" ">50" "Any" "Any" "❌ Keep Anthropic (parallelism)"
echo -e "${CYAN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${YELLOW_BOLD}Key insight:${RESET} Plan mode (Opus) should always use Anthropic cloud for quality."
echo -e "             Only consider remote Ollama for build mode (Sonnet) after establishing baseline."
echo ""

echo ""
echo -e "${CYAN_BOLD}Full reports:${RESET}"
echo -e "  $RUN1/summary.md"
echo -e "  $RUN2/summary.md"
echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
