#!/usr/bin/env bash
# test_spaceranger.sh — verify spaceranger binary is discoverable and functional
#
# Usage: ./test_spaceranger.sh [tool_path]
#
# Exit 0 if spaceranger is found and reports a version, exit 1 otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/10x_common.sh"

TOOL_PATH="${1:-}"
PASS=0
FAIL=0

_pass() { ((PASS++)); printf "${_GREEN}  PASS${_RESET} %s\n" "$*"; }
_fail() { ((FAIL++)); printf "${_RED}  FAIL${_RESET} %s\n" "$*"; }

echo "=== Space Ranger Smoke Test ==="
echo ""

# 1. Binary discovery
echo "Phase 1: Binary discovery"
BINARY=""
if BINARY=$(find_10x_binary "spaceranger" "$TOOL_PATH" 2>/dev/null); then
    _pass "spaceranger found: $BINARY"
else
    _fail "spaceranger not found"
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    exit 1
fi

# 2. Version check
echo ""
echo "Phase 2: Version check"
VERSION=$(get_10x_version "$BINARY")
if [[ "$VERSION" != "unknown" && -n "$VERSION" ]]; then
    _pass "Version: $VERSION"
else
    _fail "Could not determine version"
fi

# 3. Help output
echo ""
echo "Phase 3: Help output"
if "$BINARY" count --help &>/dev/null; then
    _pass "spaceranger count --help exits successfully"
else
    _fail "spaceranger count --help failed"
fi

# 4. Sitecheck
echo ""
echo "Phase 4: Site check"
if "$BINARY" sitecheck &>/dev/null; then
    _pass "spaceranger sitecheck passed"
else
    _fail "spaceranger sitecheck failed (may still work)"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
