#!/usr/bin/env bash
# validate_cellranger_multi.sh — config validation for cellranger-multi-run.sh
# Sourced by the HPC repo's validate.sh; defines validate_cellranger_multi().

validate_cellranger_multi() {
    local config="$1"
    local errors=0

    # Required top-level keys
    for key in sample_id localcores localmem transcriptome; do
        if ! yaml_get "$config" "$key" &>/dev/null; then
            echo "ERROR: missing required key: $key"
            errors=$((errors + 1))
        fi
    done

    # create_bam required for Cell Ranger 10.0.0+
    if ! grep -q "^create_bam:" "$config"; then
        echo "ERROR: create_bam is required for Cell Ranger 10.0.0+. Add 'create_bam: true' to your config."
        errors=$((errors + 1))
    fi

    # libraries list must be present
    if ! grep -q "^libraries:" "$config"; then
        echo "ERROR: libraries list is required. Add a 'libraries:' block with at least one entry."
        errors=$((errors + 1))
    fi

    # Validate numeric fields
    local localcores localmem
    localcores=$(yaml_get "$config" "localcores" 2>/dev/null || echo "")
    localmem=$(yaml_get "$config" "localmem" 2>/dev/null || echo "")
    if [[ -n "$localcores" ]] && ! [[ "$localcores" =~ ^[0-9]+$ ]]; then
        echo "ERROR: localcores must be a positive integer, got: $localcores"
        errors=$((errors + 1))
    fi
    if [[ -n "$localmem" ]] && ! [[ "$localmem" =~ ^[0-9]+$ ]]; then
        echo "ERROR: localmem must be a positive integer, got: $localmem"
        errors=$((errors + 1))
    fi

    # Validate transcriptome path exists
    local transcriptome
    transcriptome=$(yaml_get "$config" "transcriptome" 2>/dev/null || echo "")
    if [[ -n "$transcriptome" && ! -d "$transcriptome" ]]; then
        echo "ERROR: transcriptome path does not exist: $transcriptome"
        errors=$((errors + 1))
    fi

    # Validate optional reference paths if present
    local vdj_reference feat_reference
    vdj_reference=$(yaml_get "$config" "vdj_reference" 2>/dev/null || echo "")
    if [[ -n "$vdj_reference" && ! -d "$vdj_reference" ]]; then
        echo "ERROR: vdj_reference path does not exist: $vdj_reference"
        errors=$((errors + 1))
    fi
    feat_reference=$(yaml_get "$config" "feature_reference" 2>/dev/null || echo "")
    if [[ -n "$feat_reference" && ! -f "$feat_reference" ]]; then
        echo "ERROR: feature_reference file does not exist: $feat_reference"
        errors=$((errors + 1))
    fi

    return $errors
}
