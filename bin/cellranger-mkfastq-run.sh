#!/usr/bin/env bash
# cellranger-mkfastq-run.sh — wrapper that translates YAML config into a cellranger mkfastq invocation
#
# Usage: cellranger-mkfastq-run.sh <config.yaml> <scratch_output_dir>
#
# Called by the SLURM template; not invoked directly by users.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/10x_common.sh"

# ── Arguments ────────────────────────────────────────────────────────────────
CONFIG="${1:?Usage: cellranger-mkfastq-run.sh <config.yaml> <scratch_output_dir>}"
SCRATCH_OUTPUT_DIR="${2:?Usage: cellranger-mkfastq-run.sh <config.yaml> <scratch_output_dir>}"

if [[ ! -f "$CONFIG" ]]; then
    die "Config file not found: $CONFIG"
fi

# ── Read config ──────────────────────────────────────────────────────────────
require_config_keys "$CONFIG" run_id run_dir samplesheet localcores localmem

run_id=$(yaml_get "$CONFIG" "run_id")
run_dir=$(yaml_get "$CONFIG" "run_dir")
samplesheet=$(yaml_get "$CONFIG" "samplesheet")
localcores=$(yaml_get "$CONFIG" "localcores")
localmem=$(yaml_get "$CONFIG" "localmem")
tool_path=$(yaml_get "$CONFIG" "tool_path" 2>/dev/null || echo "")

# Optional parameters
lanes=$(yaml_get "$CONFIG" "lanes" 2>/dev/null || echo "")
rc_i2_override=$(yaml_get "$CONFIG" "rc_i2_override" 2>/dev/null || echo "")
filter_single_index=$(yaml_get "$CONFIG" "filter_single_index" 2>/dev/null || echo "")
filter_dual_index=$(yaml_get "$CONFIG" "filter_dual_index" 2>/dev/null || echo "")
qc=$(yaml_get "$CONFIG" "qc" 2>/dev/null || echo "")

# ── Locate binary ────────────────────────────────────────────────────────────
CELLRANGER=$(find_10x_binary "cellranger" "$tool_path")
info "Using cellranger: $CELLRANGER"
info "Version: $(get_10x_version "$CELLRANGER")"

# ── Validate paths ───────────────────────────────────────────────────────────
require_paths_exist "$CONFIG" run_dir samplesheet

# ── Build command ────────────────────────────────────────────────────────────
info "Run ID: $run_id"
info "BCL run dir: $run_dir"
info "SampleSheet: $samplesheet"
info "Resources: $localcores cores, ${localmem}GB memory"
info "Output dir: $SCRATCH_OUTPUT_DIR"

# Cell Ranger writes output as <cwd>/<id>/outs/
cd "$SCRATCH_OUTPUT_DIR"

CMD=(
    "$CELLRANGER" mkfastq
    --id="$run_id"
    --run="$run_dir"
    --samplesheet="$samplesheet"
    --localcores="$localcores"
    --localmem="$localmem"
)

# Append optional flags
[[ -n "$lanes" ]] && CMD+=(--lanes="$lanes")
[[ -n "$rc_i2_override" ]] && CMD+=(--rc-i2-override="$rc_i2_override")
[[ -n "$filter_single_index" && "$filter_single_index" == "true" ]] && CMD+=(--filter-single-index)
[[ -n "$filter_dual_index" && "$filter_dual_index" == "true" ]] && CMD+=(--filter-dual-index)
[[ -n "$qc" && "$qc" == "true" ]] && CMD+=(--qc)

# ── Execute ──────────────────────────────────────────────────────────────────
info "Running: ${CMD[*]}"
"${CMD[@]}"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    info "cellranger mkfastq completed successfully."
else
    error "cellranger mkfastq failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
