#!/usr/bin/env bash

# Coverage collection script for bash scripts
# Uses kcov for coverage collection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up coverage collection...${NC}"

# Check if kcov is available
if ! command -v kcov >/dev/null 2>&1; then
    echo -e "${YELLOW}kcov not available, skipping coverage...${NC}"
    echo -e "${YELLOW}Install manually: apt-get install kcov-dev or yum install kcov${NC}"
else
    echo -e "${GREEN}kcov found, proceeding with coverage...${NC}"
fi
fi

# Create coverage directory
mkdir -p coverage

echo -e "${GREEN}Running tests with coverage...${NC}"

# Run unit tests with coverage
cd "$(dirname "$0")"

# Run tests with kcov
kcov --include-path=. --exclude-pattern=test,.git coverage/ ./bash_unit test_plugin_system.sh test_with_wrapper.sh test_isolated_final.sh

echo -e "${GREEN}Coverage report generated in coverage/ directory${NC}"

# Show coverage summary
if [ -f "coverage/index.html" ]; then
    echo -e "${YELLOW}Coverage report available at coverage/index.html${NC}"
    
    # Extract coverage percentage from HTML
    if command -v grep >/dev/null 2>&1 && command -v sed >/dev/null 2>&1; then
        COVERAGE=$(grep -o 'covered.*%' coverage/index.html | head -1 | sed 's/.*covered //' | sed 's/%.*//')
        if [ -n "$COVERAGE" ]; then
            echo -e "${GREEN}Coverage: ${COVERAGE}%${NC}"
            echo "$COVERAGE" > coverage/percentage.txt
        fi
    fi
fi
