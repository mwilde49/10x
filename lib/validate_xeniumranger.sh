#!/usr/bin/env bash
# validate_xeniumranger.sh — config validation for xeniumranger pipelines
# Sourced by the HPC repo's validate.sh; never executed directly.

# validate_xeniumranger <config_file>
# Returns 0 on success, 1 on failure. Prints all errors before returning.
validate_xeniumranger() {
    local config="$1"
    local errors=()

    # Required keys (common to all commands)
    local required_keys=(sample_id command xenium_bundle localcores localmem)
    for key in "${required_keys[@]}"; do
        if ! yaml_has "$config" "$key"; then
            errors+=("Missing required key: $key")
        fi
    done

    # Validate command value
    local command=""
    if yaml_has "$config" "command"; then
        command=$(yaml_get "$config" "command") || true
        if [[ "$command" != "resegment" && "$command" != "import-segmentation" ]]; then
            errors+=("command must be 'resegment' or 'import-segmentation', got: $command")
        fi
    fi

    # Command-specific required keys
    if [[ "$command" == "import-segmentation" ]]; then
        if ! yaml_has "$config" "segmentation_file"; then
            errors+=("Missing required key for import-segmentation: segmentation_file")
        fi
    fi

    # Path existence (skip placeholders)
    local path_keys=(xenium_bundle)
    [[ "$command" == "import-segmentation" ]] && path_keys+=(segmentation_file)
    for key in "${path_keys[@]}"; do
        if yaml_has "$config" "$key"; then
            local val
            val=$(yaml_get "$config" "$key") || continue
            [[ "$val" == __* ]] && continue
            if [[ ! -e "$val" ]]; then
                errors+=("Path does not exist for $key: $val")
            fi
        fi
    done

    # Numeric validation
    for key in localcores localmem; do
        if yaml_has "$config" "$key"; then
            local val
            val=$(yaml_get "$config" "$key") || continue
            if [[ ! "$val" =~ ^[0-9]+$ ]]; then
                errors+=("$key must be a positive integer, got: $val")
            fi
        fi
    done

    # Tool path validation
    if yaml_has "$config" "tool_path"; then
        local tp
        tp=$(yaml_get "$config" "tool_path") || true
        if [[ -n "$tp" && "$tp" != __* && ! -d "$tp" && ! -x "$tp" ]]; then
            errors+=("tool_path does not exist: $tp")
        fi
    fi

    # Report errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        for e in "${errors[@]}"; do
            error "  $e"
        done
        return 1
    fi
    return 0
}
