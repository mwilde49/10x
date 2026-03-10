#!/usr/bin/env bash
# 10x_common.sh — shared constants and helpers for 10x Genomics pipeline wrappers
# Sourced by bin/*-run.sh scripts; never executed directly.

set -euo pipefail

# ── Repo root ────────────────────────────────────────────────────────────────
TENX_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Supported tools ──────────────────────────────────────────────────────────
TENX_TOOLS=(cellranger spaceranger xeniumranger)

# ── Color output ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    _RED='\033[0;31m'
    _YELLOW='\033[0;33m'
    _GREEN='\033[0;32m'
    _CYAN='\033[0;36m'
    _BOLD='\033[1m'
    _RESET='\033[0m'
else
    _RED='' _YELLOW='' _GREEN='' _CYAN='' _BOLD='' _RESET=''
fi

_ts()    { date '+%H:%M:%S'; }
info()   { printf "${_CYAN}[%s]${_RESET} ${_GREEN}[INFO]${_RESET}  %s\n" "$(_ts)" "$*"; }
warn()   { printf "${_CYAN}[%s]${_RESET} ${_YELLOW}[WARN]${_RESET}  %s\n" "$(_ts)" "$*" >&2; }
error()  { printf "${_CYAN}[%s]${_RESET} ${_RED}[ERROR]${_RESET} %s\n" "$(_ts)" "$*" >&2; }
die()    { error "$@"; exit 1; }

# ── YAML helpers ─────────────────────────────────────────────────────────────
# yaml_get <file> <key>
# Reads a flat YAML key-value pair. Handles: key: value and key: "value"
# Returns empty string + exit 1 if key not found.
yaml_get() {
    local file="$1" key="$2"
    local val
    val=$(grep -E "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^['\"]//; s/['\"]$//" || true)
    if [[ -z "$val" ]]; then
        return 1
    fi
    printf '%s' "$val"
}

# yaml_has <file> <key>
# Returns 0 if the key exists in the file.
yaml_has() {
    local file="$1" key="$2"
    grep -qE "^${key}:" "$file" 2>/dev/null
}

# ── Tool discovery ───────────────────────────────────────────────────────────

# find_10x_binary <tool_name> [tool_path]
# Locates the 10x tool binary. Checks:
#   1. Explicit tool_path argument (from config YAML)
#   2. $PATH
#   3. Common HPC install locations
# Prints the full path to the binary on success, exits on failure.
find_10x_binary() {
    local tool="$1"
    local tool_path="${2:-}"

    # 1. Explicit path from config
    if [[ -n "$tool_path" ]]; then
        # tool_path may be a directory containing the binary, or the binary itself
        if [[ -x "$tool_path/$tool" ]]; then
            printf '%s' "$tool_path/$tool"
            return 0
        elif [[ -x "$tool_path" && "$(basename "$tool_path")" == "$tool" ]]; then
            printf '%s' "$tool_path"
            return 0
        else
            die "$tool not found at configured tool_path: $tool_path"
        fi
    fi

    # 2. Check $PATH
    if command -v "$tool" &>/dev/null; then
        command -v "$tool"
        return 0
    fi

    # 3. Common HPC install locations
    local common_paths=(
        "/groups/tprice/software/$tool"
        "/groups/tprice/software/$tool/bin"
        "/opt/$tool"
        "/opt/$tool/bin"
        "/usr/local/bin"
    )
    for p in "${common_paths[@]}"; do
        if [[ -x "$p/$tool" ]]; then
            printf '%s' "$p/$tool"
            return 0
        fi
    done

    die "$tool binary not found. Set tool_path in your config YAML or add it to \$PATH."
}

# get_10x_version <binary_path>
# Extracts the version string from a 10x tool.
# All 10x tools support: <tool> --version
get_10x_version() {
    local binary="$1"
    "$binary" --version 2>/dev/null | head -1 || echo "unknown"
}

# ── Config reading ───────────────────────────────────────────────────────────

# require_config_keys <config_file> <key1> [key2 ...]
# Dies if any required key is missing from the config.
require_config_keys() {
    local config="$1"
    shift
    local missing=()
    for key in "$@"; do
        if ! yaml_has "$config" "$key"; then
            missing+=("$key")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required config keys: ${missing[*]}"
    fi
}

# require_paths_exist <config_file> <key1> [key2 ...]
# Dies if any path referenced by these config keys does not exist.
# Skips keys with placeholder values (__SCRATCH__, etc.).
require_paths_exist() {
    local config="$1"
    shift
    for key in "$@"; do
        if yaml_has "$config" "$key"; then
            local val
            val=$(yaml_get "$config" "$key") || continue
            # Skip placeholders
            [[ "$val" == __* ]] && continue
            if [[ ! -e "$val" ]]; then
                die "Path does not exist for $key: $val"
            fi
        fi
    done
}

# require_numeric <config_file> <key1> [key2 ...]
# Dies if any of these config values are not positive integers.
require_numeric() {
    local config="$1"
    shift
    for key in "$@"; do
        if yaml_has "$config" "$key"; then
            local val
            val=$(yaml_get "$config" "$key") || continue
            if [[ ! "$val" =~ ^[0-9]+$ ]]; then
                die "$key must be a positive integer, got: $val"
            fi
        fi
    done
}
