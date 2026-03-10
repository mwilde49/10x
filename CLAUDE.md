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

## Ecosystem

This repo → HPC framework (mwilde49/hpc) consumes as submodule → `tjp-launch cellranger` dispatches to `bin/cellranger-run.sh`.

## HPC Path Conventions (Juno)

| What | Path |
|------|------|
| Cell Ranger install | `/groups/tprice/software/cellranger` |
| Space Ranger install | `/groups/tprice/software/spaceranger` |
| Xenium Ranger install | `/groups/tprice/software/xeniumranger` |
| Shared references | `/groups/tprice/pipelines/references/cellranger/` |
