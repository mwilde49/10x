#!/usr/bin/env bash
# cellranger-run.sh — wrapper that translates YAML config into a cellranger count invocation
#
# Usage: cellranger-run.sh <config.yaml> <scratch_output_dir>
#
# Called by the SLURM template; not invoked directly by users.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/10x_common.sh"

# ── Arguments ────────────────────────────────────────────────────────────────
CONFIG="${1:?Usage: cellranger-run.sh <config.yaml> <scratch_output_dir>}"
SCRATCH_OUTPUT_DIR="${2:?Usage: cellranger-run.sh <config.yaml> <scratch_output_dir>}"

if [[ ! -f "$CONFIG" ]]; then
    die "Config file not found: $CONFIG"
fi

# ── Read config ──────────────────────────────────────────────────────────────
require_config_keys "$CONFIG" sample_id sample_name fastq_dir transcriptome localcores localmem

sample_id=$(yaml_get "$CONFIG" "sample_id")
sample_name=$(yaml_get "$CONFIG" "sample_name")
fastq_dir=$(yaml_get "$CONFIG" "fastq_dir")
transcriptome=$(yaml_get "$CONFIG" "transcriptome")
localcores=$(yaml_get "$CONFIG" "localcores")
localmem=$(yaml_get "$CONFIG" "localmem")
tool_path=$(yaml_get "$CONFIG" "tool_path" 2>/dev/null || echo "")

# Optional parameters
create_bam=$(yaml_get "$CONFIG" "create_bam" 2>/dev/null || echo "")
chemistry=$(yaml_get "$CONFIG" "chemistry" 2>/dev/null || echo "")
expect_cells=$(yaml_get "$CONFIG" "expect_cells" 2>/dev/null || echo "")
force_cells=$(yaml_get "$CONFIG" "force_cells" 2>/dev/null || echo "")
include_introns=$(yaml_get "$CONFIG" "include_introns" 2>/dev/null || echo "")
no_bam=$(yaml_get "$CONFIG" "no_bam" 2>/dev/null || echo "")

# ── Locate binary ────────────────────────────────────────────────────────────
CELLRANGER=$(find_10x_binary "cellranger" "$tool_path")
info "Using cellranger: $CELLRANGER"
info "Version: $(get_10x_version "$CELLRANGER")"

# ── Validate paths ───────────────────────────────────────────────────────────
require_paths_exist "$CONFIG" fastq_dir transcriptome

# ── Build command ────────────────────────────────────────────────────────────
info "Sample: $sample_id"
info "FASTQs: $fastq_dir"
info "Reference: $transcriptome"
info "Resources: $localcores cores, ${localmem}GB memory"
info "Output dir: $SCRATCH_OUTPUT_DIR"

# Cell Ranger writes output as <cwd>/<id>/outs/
cd "$SCRATCH_OUTPUT_DIR"

CMD=(
    "$CELLRANGER" count
    --id="$sample_id"
    --transcriptome="$transcriptome"
    --fastqs="$fastq_dir"
    --sample="$sample_name"
    --localcores="$localcores"
    --localmem="$localmem"
)

# Append optional flags
[[ -n "$create_bam" ]] && CMD+=(--create-bam="$create_bam")
[[ -n "$chemistry" ]] && CMD+=(--chemistry="$chemistry")
[[ -n "$expect_cells" ]] && CMD+=(--expect-cells="$expect_cells")
[[ -n "$force_cells" ]] && CMD+=(--force-cells="$force_cells")
[[ -n "$include_introns" ]] && CMD+=(--include-introns="$include_introns")
[[ -n "$no_bam" && "$no_bam" == "true" ]] && CMD+=(--no-bam)

# ── Execute ──────────────────────────────────────────────────────────────────
info "Running: ${CMD[*]}"
"${CMD[@]}"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    info "cellranger count completed successfully."
else
    error "cellranger count failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
