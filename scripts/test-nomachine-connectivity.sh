#!/usr/bin/env bash
# test-nomachine-connectivity.sh
# Comprehensive NoMachine connectivity test suite
# Run after Tailscale ACL is applied

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test matrix
declare -A TESTS=(
    ["motoko_to_motoko"]="motoko.pangolin-vega.ts.net:4000"
    ["motoko_to_wintermute"]="wintermute.pangolin-vega.ts.net:4000"
    ["motoko_to_armitage"]="armitage.pangolin-vega.ts.net:4000"
)

PASSED=0
FAILED=0

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   NoMachine Connectivity Test Suite                          ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

for test_name in "${!TESTS[@]}"; do
    target="${TESTS[$test_name]}"
    host=$(echo "$target" | cut -d: -f1)
    port=$(echo "$target" | cut -d: -f2)
    
    echo -n "Testing $test_name ($host:$port)... "
    
    if timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC}"
        ((FAILED++))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "═══════════════════════════════════════════════════════════════"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All connectivity tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Check Tailscale ACLs and firewalls.${NC}"
    exit 1
fi


