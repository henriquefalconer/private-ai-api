#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Deep Diagnostics for Aider Installation Failure ===${NC}\n"

# 1. Check actual pip error log
echo -e "${BLUE}[1] Reading most recent pip error log...${NC}"
LATEST_LOG=$(ls -t ~/.local/pipx/logs/cmd_*_pip_errors.log 2>/dev/null | head -1)
if [[ -n "$LATEST_LOG" ]]; then
    echo -e "${GREEN}Found: $LATEST_LOG${NC}"
    echo -e "${YELLOW}--- Full pip error output ---${NC}"
    cat "$LATEST_LOG"
    echo -e "${YELLOW}--- End of log ---${NC}\n"
else
    echo -e "${RED}No pip error logs found${NC}\n"
fi

# 2. Check Python version in pipx shared environment
echo -e "${BLUE}[2] Checking pipx shared environment...${NC}"
if [[ -f ~/.local/pipx/shared/bin/python ]]; then
    SHARED_PYTHON=~/.local/pipx/shared/bin/python
    echo -e "${GREEN}Shared Python: $($SHARED_PYTHON --version)${NC}"
    echo -e "${GREEN}Shared pip: $($SHARED_PYTHON -m pip --version)${NC}"
else
    echo -e "${YELLOW}No shared environment found${NC}"
fi
echo ""

# 3. Check if we can create a venv and install numpy directly
echo -e "${BLUE}[3] Testing Python 3.13 + numpy directly...${NC}"
PYTHON313="/opt/homebrew/opt/python@3.13/libexec/bin/python"
TEST_VENV="/tmp/test-python-venv"

if [[ -x "$PYTHON313" ]]; then
    echo -e "${GREEN}Python 3.13 found: $($PYTHON313 --version)${NC}"

    # Create test venv
    rm -rf "$TEST_VENV"
    echo "Creating test venv..."
    $PYTHON313 -m venv "$TEST_VENV"

    echo "Testing numpy installation in clean venv..."
    if "$TEST_VENV/bin/pip" install --no-cache-dir numpy==1.24.3 2>&1 | tee /tmp/numpy-test.log; then
        echo -e "${GREEN}✓ numpy 1.24.3 installed successfully in test venv${NC}"
        NUMPY_VERSION=$("$TEST_VENV/bin/python" -c "import numpy; print(numpy.__version__)")
        echo -e "${GREEN}✓ numpy version: $NUMPY_VERSION${NC}"
    else
        echo -e "${RED}✗ numpy 1.24.3 failed to install${NC}"
        echo -e "${YELLOW}Trying latest numpy instead...${NC}"
        if "$TEST_VENV/bin/pip" install numpy 2>&1 | tee /tmp/numpy-latest-test.log; then
            NUMPY_VERSION=$("$TEST_VENV/bin/python" -c "import numpy; print(numpy.__version__)")
            echo -e "${GREEN}✓ Latest numpy ($NUMPY_VERSION) works${NC}"
            echo -e "${YELLOW}Issue: Aider requires numpy==1.24.3 which doesn't support Python 3.13${NC}"
        else
            echo -e "${RED}✗ Even latest numpy fails - something else is wrong${NC}"
        fi
    fi

    # Cleanup
    rm -rf "$TEST_VENV"
else
    echo -e "${RED}Python 3.13 not found at $PYTHON313${NC}"
fi
echo ""

# 4. Check available numpy wheels for Python 3.13
echo -e "${BLUE}[4] Checking available numpy wheels...${NC}"
echo "Querying PyPI for numpy 1.24.3 wheels..."
curl -s https://pypi.org/pypi/numpy/1.24.3/json | \
    python3 -c "import sys, json; data = json.load(sys.stdin); [print(u['filename']) for u in data['urls'] if 'cp313' in u['filename'] or 'cp3' not in u['filename']]" 2>/dev/null || \
    echo -e "${YELLOW}Could not query PyPI (network issue or jq not available)${NC}"
echo ""

# 5. Check build tools
echo -e "${BLUE}[5] Checking build dependencies...${NC}"
for tool in gcc g++ make; do
    if command -v $tool &>/dev/null; then
        echo -e "${GREEN}✓ $tool found: $(command -v $tool)${NC}"
    else
        echo -e "${RED}✗ $tool not found${NC}"
    fi
done
echo ""

# 6. Check Xcode Command Line Tools
echo -e "${BLUE}[6] Checking Xcode Command Line Tools...${NC}"
if xcode-select -p &>/dev/null; then
    echo -e "${GREEN}✓ Xcode CLT installed: $(xcode-select -p)${NC}"
else
    echo -e "${RED}✗ Xcode Command Line Tools not installed${NC}"
    echo -e "${YELLOW}This is required for building Python packages from source${NC}"
fi
echo ""

# 7. Summary and recommendations
echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo "Based on the diagnostics above, the most likely issues are:"
echo ""
echo "A. numpy 1.24.3 has no pre-built wheels for Python 3.13"
echo "   → Solution: Upgrade Aider to use a newer numpy, or downgrade Python to 3.12"
echo ""
echo "B. Missing build tools (Xcode CLT, gcc, etc.)"
echo "   → Solution: xcode-select --install"
echo ""
echo "C. pip/setuptools in pipx shared environment has issues"
echo "   → Solution: Manually recreate pipx environment"
echo ""
echo "Check the pip error log above to see which issue matches."
