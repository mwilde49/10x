#!/usr/bin/env bash
# spaceranger-run.sh — wrapper that translates YAML config into a spaceranger count invocation
#
# Usage: spaceranger-run.sh <config.yaml> <scratch_output_dir>
#
# Called by the SLURM template; not invoked directly by users.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/10x_common.sh"

# ── Arguments ────────────────────────────────────────────────────────────────
CONFIG="${1:?Usage: spaceranger-run.sh <config.yaml> <scratch_output_dir>}"
SCRATCH_OUTPUT_DIR="${2:?Usage: spaceranger-run.sh <config.yaml> <scratch_output_dir>}"

if [[ ! -f "$CONFIG" ]]; then
    die "Config file not found: $CONFIG"
fi

# ── Read config ──────────────────────────────────────────────────────────────
require_config_keys "$CONFIG" sample_id sample_name fastq_dir transcriptome image localcores localmem

sample_id=$(yaml_get "$CONFIG" "sample_id")
sample_name=$(yaml_get "$CONFIG" "sample_name")
fastq_dir=$(yaml_get "$CONFIG" "fastq_dir")
transcriptome=$(yaml_get "$CONFIG" "transcriptome")
image=$(yaml_get "$CONFIG" "image")
slide=$(yaml_get "$CONFIG" "slide" 2>/dev/null || echo "")
area=$(yaml_get "$CONFIG" "area" 2>/dev/null || echo "")
unknown_slide=$(yaml_get "$CONFIG" "unknown_slide" 2>/dev/null || echo "")
localcores=$(yaml_get "$CONFIG" "localcores")
localmem=$(yaml_get "$CONFIG" "localmem")
tool_path=$(yaml_get "$CONFIG" "tool_path" 2>/dev/null || echo "")

# Optional parameters
cytaimage=$(yaml_get "$CONFIG" "cytaimage" 2>/dev/null || echo "")
darkimage=$(yaml_get "$CONFIG" "darkimage" 2>/dev/null || echo "")
colorizedimage=$(yaml_get "$CONFIG" "colorizedimage" 2>/dev/null || echo "")
reorient_images=$(yaml_get "$CONFIG" "reorient_images" 2>/dev/null || echo "")
loupe_alignment=$(yaml_get "$CONFIG" "loupe_alignment" 2>/dev/null || echo "")
create_bam=$(yaml_get "$CONFIG" "create_bam" 2>/dev/null || echo "")
no_bam=$(yaml_get "$CONFIG" "no_bam" 2>/dev/null || echo "")

# ── Locate binary ────────────────────────────────────────────────────────────
SPACERANGER=$(find_10x_binary "spaceranger" "$tool_path")
info "Using spaceranger: $SPACERANGER"
info "Version: $(get_10x_version "$SPACERANGER")"

# ── Validate paths ───────────────────────────────────────────────────────────
require_paths_exist "$CONFIG" fastq_dir transcriptome image

# ── Build command ────────────────────────────────────────────────────────────
info "Sample: $sample_id"
info "FASTQs: $fastq_dir"
info "Image: $image"
if [[ -n "$unknown_slide" ]]; then
    info "Slide: unknown ($unknown_slide)"
else
    info "Slide: $slide / Area: $area"
fi
info "Reference: $transcriptome"
info "Resources: $localcores cores, ${localmem}GB memory"
info "Output dir: $SCRATCH_OUTPUT_DIR"

# Space Ranger writes output as <cwd>/<id>/outs/
cd "$SCRATCH_OUTPUT_DIR"

CMD=(
    "$SPACERANGER" count
    --id="$sample_id"
    --transcriptome="$transcriptome"
    --fastqs="$fastq_dir"
    --sample="$sample_name"
    --image="$image"
    --localcores="$localcores"
    --localmem="$localmem"
)

# Slide identification: either slide+area or unknown_slide
if [[ -n "$unknown_slide" ]]; then
    CMD+=(--unknown-slide="$unknown_slide")
else
    CMD+=(--slide="$slide" --area="$area")
fi

# Append optional flags
[[ -n "$cytaimage" ]] && CMD+=(--cytaimage="$cytaimage")
[[ -n "$darkimage" ]] && CMD+=(--darkimage="$darkimage")
[[ -n "$colorizedimage" ]] && CMD+=(--colorizedimage="$colorizedimage")
[[ -n "$reorient_images" && "$reorient_images" == "true" ]] && CMD+=(--reorient-images)
[[ -n "$loupe_alignment" ]] && CMD+=(--loupe-alignment="$loupe_alignment")
[[ -n "$create_bam" ]] && CMD+=(--create-bam="$create_bam")
[[ -n "$no_bam" && "$no_bam" == "true" ]] && CMD+=(--no-bam)

# ── Execute ──────────────────────────────────────────────────────────────────
info "Running: ${CMD[*]}"
"${CMD[@]}"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    info "spaceranger count completed successfully."
else
    error "spaceranger count failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
