#!/usr/bin/env bash
# xeniumranger-run.sh — wrapper that translates YAML config into a xeniumranger invocation
#
# Usage: xeniumranger-run.sh <config.yaml> <scratch_output_dir>
#
# Supports two commands:
#   command: resegment           — re-segment cells from a Xenium output bundle
#   command: import-segmentation — import external segmentation masks
#
# Called by the SLURM template; not invoked directly by users.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/10x_common.sh"

# ── Arguments ────────────────────────────────────────────────────────────────
CONFIG="${1:?Usage: xeniumranger-run.sh <config.yaml> <scratch_output_dir>}"
SCRATCH_OUTPUT_DIR="${2:?Usage: xeniumranger-run.sh <config.yaml> <scratch_output_dir>}"

if [[ ! -f "$CONFIG" ]]; then
    die "Config file not found: $CONFIG"
fi

# ── Read common config ───────────────────────────────────────────────────────
require_config_keys "$CONFIG" sample_id command xenium_bundle localcores localmem

sample_id=$(yaml_get "$CONFIG" "sample_id")
command=$(yaml_get "$CONFIG" "command")
xenium_bundle=$(yaml_get "$CONFIG" "xenium_bundle")
localcores=$(yaml_get "$CONFIG" "localcores")
localmem=$(yaml_get "$CONFIG" "localmem")
tool_path=$(yaml_get "$CONFIG" "tool_path" 2>/dev/null || echo "")

# ── Locate binary ────────────────────────────────────────────────────────────
XENIUMRANGER=$(find_10x_binary "xeniumranger" "$tool_path")
info "Using xeniumranger: $XENIUMRANGER"
info "Version: $(get_10x_version "$XENIUMRANGER")"

# ── Validate common paths ───────────────────────────────────────────────────
require_paths_exist "$CONFIG" xenium_bundle

# ── Dispatch by command ──────────────────────────────────────────────────────
cd "$SCRATCH_OUTPUT_DIR"

case "$command" in
    resegment)
        info "Command: resegment"
        info "Sample: $sample_id"
        info "Xenium bundle: $xenium_bundle"
        info "Resources: $localcores cores, ${localmem}GB memory"
        info "Output dir: $SCRATCH_OUTPUT_DIR"

        # Optional resegment parameters
        expansion_distance=$(yaml_get "$CONFIG" "expansion_distance" 2>/dev/null || echo "")
        panel_file=$(yaml_get "$CONFIG" "panel_file" 2>/dev/null || echo "")

        CMD=(
            "$XENIUMRANGER" resegment
            --id="$sample_id"
            --xenium-bundle="$xenium_bundle"
            --localcores="$localcores"
            --localmem="$localmem"
        )

        [[ -n "$expansion_distance" ]] && CMD+=(--expansion-distance="$expansion_distance")
        [[ -n "$panel_file" ]] && CMD+=(--panel-file="$panel_file")
        ;;

    import-segmentation)
        info "Command: import-segmentation"

        require_config_keys "$CONFIG" segmentation_file
        segmentation_file=$(yaml_get "$CONFIG" "segmentation_file")
        require_paths_exist "$CONFIG" segmentation_file

        # Optional
        viz_labels=$(yaml_get "$CONFIG" "viz_labels" 2>/dev/null || echo "")

        info "Sample: $sample_id"
        info "Xenium bundle: $xenium_bundle"
        info "Segmentation: $segmentation_file"
        info "Resources: $localcores cores, ${localmem}GB memory"
        info "Output dir: $SCRATCH_OUTPUT_DIR"

        CMD=(
            "$XENIUMRANGER" import-segmentation
            --id="$sample_id"
            --xenium-bundle="$xenium_bundle"
            --segmentation="$segmentation_file"
            --localcores="$localcores"
            --localmem="$localmem"
        )

        [[ -n "$viz_labels" ]] && CMD+=(--viz-labels="$viz_labels")
        ;;

    *)
        die "Unknown command: $command (supported: resegment, import-segmentation)"
        ;;
esac

# ── Execute ──────────────────────────────────────────────────────────────────
info "Running: ${CMD[*]}"
"${CMD[@]}"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    info "xeniumranger $command completed successfully."
else
    error "xeniumranger $command failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
