#!/usr/bin/env bash
# validate_spaceranger.sh — config validation for spaceranger pipelines
# Sourced by the HPC repo's validate.sh; never executed directly.

# validate_spaceranger <config_file>
# Returns 0 on success, 1 on failure. Prints all errors before returning.
validate_spaceranger() {
    local config="$1"
    local errors=()

    # Required keys (slide/area OR unknown_slide, validated below)
    local required_keys=(sample_id sample_name fastq_dir transcriptome image localcores localmem)
    for key in "${required_keys[@]}"; do
        if ! yaml_has "$config" "$key"; then
            errors+=("Missing required key: $key")
        fi
    done

    # Must have either (slide + area) or unknown_slide
    local has_slide=false has_area=false has_unknown_slide=false
    yaml_has "$config" "slide" && has_slide=true
    yaml_has "$config" "area" && has_area=true
    yaml_has "$config" "unknown_slide" && has_unknown_slide=true

    if ! $has_unknown_slide; then
        $has_slide || errors+=("Missing required key: slide (or use unknown_slide)")
        $has_area || errors+=("Missing required key: area (or use unknown_slide)")
    fi

    # Path existence (skip placeholders)
    local path_keys=(fastq_dir transcriptome image)
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

    # Slide format validation (e.g., V19L29-096)
    if yaml_has "$config" "slide"; then
        local slide
        slide=$(yaml_get "$config" "slide") || true
        if [[ -n "$slide" && ! "$slide" =~ ^[A-Z0-9]+-[A-Z0-9]+$ && "$slide" != __* ]]; then
            errors+=("slide format looks unusual (expected e.g. V19L29-096): $slide")
        fi
    fi

    # Area validation (e.g., A1, B1, C1, D1)
    if yaml_has "$config" "area"; then
        local area
        area=$(yaml_get "$config" "area") || true
        if [[ -n "$area" && ! "$area" =~ ^[A-D]1$ && "$area" != __* ]]; then
            errors+=("area must be A1, B1, C1, or D1, got: $area")
        fi
    fi

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
