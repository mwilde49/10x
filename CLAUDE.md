# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

10x Genomics pipeline wrapper repo for Cell Ranger, Space Ranger, and Xenium Ranger. Provides config-driven YAML-to-CLI translation, validation, and test scripts. Consumed by [mwilde49/hpc](https://github.com/mwilde49/hpc) as a git submodule at `containers/10x/`.

## Key Difference from Other Pipeline Repos

Unlike `bulkseq` (container-only) and `psoma` (combined pipeline + container), this repo has **no Apptainer container and no Nextflow**. The 10x tools are self-contained — they manage their own parallelism via `--localcores`/`--localmem` and bundle their own dependencies. The orchestration stack simplifies from `SLURM → Apptainer → Nextflow → Config` to `SLURM → 10x CLI`.

The tarballs are pre-installed on HPC. This repo provides wrapper scripts that the HPC repo's SLURM templates call.

## Architecture

- **`bin/*-run.sh`** — Wrapper scripts that read YAML config and construct 10x CLI invocations. Each wrapper: sources `lib/10x_common.sh`, validates config, locates the binary, builds the command, `cd`s to scratch, and executes.
- **`lib/10x_common.sh`** — Shared helpers: YAML parsing, tool binary discovery, path/numeric validation.
- **`lib/validate_*.sh`** — Per-tool config validation functions. Sourced by the HPC repo's `validate.sh`.
- **`test/test_*.sh`** — Smoke tests that verify binary discovery, version output, and help accessibility.

## Key Commands

```bash
# Run smoke tests (requires tools installed on HPC)
bash test/test_cellranger.sh [/path/to/cellranger]
bash test/test_spaceranger.sh [/path/to/spaceranger]
bash test/test_xeniumranger.sh [/path/to/xeniumranger]
```

## Supported 10x Commands

- **Cell Ranger**: `cellranger count` (scRNA-seq)
- **Space Ranger**: `spaceranger count` (Visium spatial transcriptomics)
- **Xenium Ranger**: `xeniumranger resegment`, `xeniumranger import-segmentation` (Xenium in-situ)

## Important Conventions

- 10x tools write output relative to CWD — wrapper scripts `cd` to `$SCRATCH_OUTPUT_DIR` before invocation.
- `tool_path` in config points to the directory containing the tool binary (e.g., `/groups/tprice/software/cellranger`).
- `localcores`/`localmem` must not exceed SLURM allocation.
- SLURM templates use `--exclusive` because 10x tools manage their own threading.
- One sample per launch (consistent with existing pipeline patterns).

### Critical Requirements (Cell Ranger 10.0.0+ and Space Ranger 3.0+)

`create_bam: true` is REQUIRED in the user config for Cell Ranger 10.0.0+ and Space Ranger 3.0+.
Without this field, the tool will error. Default is not set — users must explicitly include it.

The validator in `lib/validate_cellranger.sh` and `lib/validate_spaceranger.sh` MUST check
for this field's presence and produce a clear error if missing.

## Versioning Notes

- **v1.0.0**: Initial release — Cell Ranger, Space Ranger, Xenium Ranger wrapper scripts.
- **v1.1.0**: Adds `unknown_slide` support in `bin/spaceranger-run.sh` (used in smoke testing when slide/area are not available; pass `unknown_slide: visium-1` in config instead of `slide` + `area`).

## Ecosystem

This repo → HPC framework (mwilde49/hpc) consumes as submodule → `tjp-launch cellranger` dispatches to `bin/cellranger-run.sh`.

## HPC Path Conventions (Juno)

| What | Path |
|------|------|
| Cell Ranger install | `/groups/tprice/software/cellranger` |
| Space Ranger install | `/groups/tprice/software/spaceranger` |
| Xenium Ranger install | `/groups/tprice/software/xeniumranger` |
| Shared references | `/groups/tprice/pipelines/references/cellranger/` |

## Tool Paths on Juno HPC

Versioned installs:
- `/groups/tprice/opt/cellranger-10.0.0/`
- `/groups/tprice/opt/spaceranger-4.0.1/`
- `/groups/tprice/opt/xeniumranger-xenium4.0/`

Symlinks (point to above):
- `/groups/tprice/software/cellranger` → `cellranger-10.0.0`
- `/groups/tprice/software/spaceranger` → `spaceranger-4.0.1`
- `/groups/tprice/software/xeniumranger` → `xeniumranger-xenium4.0`

The framework's `PIPELINE_TOOL_PATHS` array in `bin/lib/common.sh` points to the symlinks.
Users can override with `tool_path:` in their config YAML to target a specific version.

To upgrade a tool:
1. Extract new tarball to `/groups/tprice/opt/<tool>-<version>/`
2. Update symlink: `ln -sfn /groups/tprice/opt/<tool>-<version> /groups/tprice/software/<tool>`
3. No changes needed to this submodule or the HPC repo

## Titan Integration (Hyperion Compute v6.0.0)

The parent HPC framework passes Titan metadata fields from the user config YAML.
These are NOT used by the wrapper scripts — they are read by the framework layer only.

Config fields added to templates (do NOT consume in wrapper scripts):
- `titan_project_id` → PRJ-xxxx
- `titan_sample_id` → SMP-xxxx
- `titan_library_id` → LIB-xxxx
- `titan_run_id` → RUN-xxxx

Note: cellranger/spaceranger/xeniumranger already use `sample_id` natively.
The Titan fields use the `titan_` prefix specifically to avoid this collision.
The validator must NOT reject configs that have both `sample_id` (native) and
`titan_sample_id` (framework metadata) — they serve different purposes.

## Batch Execution via Samplesheets (Hyperion Compute v6.0.0)

The parent framework supports batch execution via `tjp-batch`. Samplesheet columns:

Cell Ranger:    sample, fastqs, transcriptome [, project_id, sample_id, library_id, run_id]
Space Ranger:   sample, fastqs, transcriptome, image, slide, area [, project_id, ...]
Xenium Ranger:  sample, xenium_bundle, command [, project_id, ...]

The batch launcher calls wrapper scripts one row at a time (per-row mode),
generating a separate config YAML per row. The wrapper scripts themselves are
unchanged — they see a standard single-sample config.

`sample_id` in the samplesheet maps to the native `sample_id` config key.
`project_id` in the samplesheet maps to the Titan `titan_project_id` config key.
(The CSV uses unprefixed names; the framework adds the `titan_` prefix when writing config.)
