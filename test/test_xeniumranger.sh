#!/usr/bin/env bash
# test_xeniumranger.sh — verify xeniumranger binary is discoverable and functional
#
# Usage: ./test_xeniumranger.sh [tool_path]
#
# Exit 0 if xeniumranger is found and reports a version, exit 1 otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/10x_common.sh"

TOOL_PATH="${1:-}"
PASS=0
FAIL=0

_pass() { ((PASS++)); printf "${_GREEN}  PASS${_RESET} %s\n" "$*"; }
_fail() { ((FAIL++)); printf "${_RED}  FAIL${_RESET} %s\n" "$*"; }

echo "=== Xenium Ranger Smoke Test ==="
echo ""

# 1. Binary discovery
echo "Phase 1: Binary discovery"
BINARY=""
if BINARY=$(find_10x_binary "xeniumranger" "$TOOL_PATH" 2>/dev/null); then
    _pass "xeniumranger found: $BINARY"
else
    _fail "xeniumranger not found"
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
if "$BINARY" resegment --help &>/dev/null; then
    _pass "xeniumranger resegment --help exits successfully"
else
    _fail "xeniumranger resegment --help failed"
fi

if "$BINARY" import-segmentation --help &>/dev/null; then
    _pass "xeniumranger import-segmentation --help exits successfully"
else
    _fail "xeniumranger import-segmentation --help failed"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
