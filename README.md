# 10x Genomics Pipeline Wrappers

Config-driven wrappers for Cell Ranger, Space Ranger, and Xenium Ranger. Translates YAML configs into CLI invocations for HPC deployment.

This repo is consumed by the [HPC deployment framework](https://github.com/mwilde49/hpc) as a git submodule. Unlike the [bulkseq](https://github.com/mwilde49/bulkseq) and [psoma](https://github.com/mwilde49/psoma) repos, there is no Apptainer container or Nextflow workflow — 10x tools are self-contained and manage their own parallelism.

## Supported Tools

| Tool | Command | Modality |
|------|---------|----------|
| Cell Ranger | `cellranger count` | scRNA-seq, multimodal |
| Space Ranger | `spaceranger count` | Visium spatial transcriptomics |
| Xenium Ranger | `xeniumranger resegment` | Xenium in-situ spatial |
| Xenium Ranger | `xeniumranger import-segmentation` | Xenium in-situ spatial |

## Directory Structure

```
10x/
├── bin/
│   ├── cellranger-run.sh         # YAML → cellranger count
│   ├── spaceranger-run.sh        # YAML → spaceranger count
│   └── xeniumranger-run.sh       # YAML → xeniumranger resegment/import-segmentation
├── lib/
│   ├── 10x_common.sh             # Shared helpers (tool discovery, YAML, validation)
│   ├── validate_cellranger.sh    # Config validation for cellranger
│   ├── validate_spaceranger.sh   # Config validation for spaceranger
│   └── validate_xeniumranger.sh  # Config validation for xeniumranger
├── test/
│   ├── test_cellranger.sh        # Smoke test: binary + version
│   ├── test_spaceranger.sh       # Smoke test: binary + version
│   └── test_xeniumranger.sh      # Smoke test: binary + version
├── VERSION
├── CLAUDE.md
└── README.md
```

## Quick Start

### Smoke Tests

Verify tools are installed and accessible on your HPC:

```bash
bash test/test_cellranger.sh                              # auto-discover
bash test/test_cellranger.sh /groups/tprice/software/cellranger  # explicit path
bash test/test_spaceranger.sh
bash test/test_xeniumranger.sh
```

### Using from the HPC Repo

This repo is consumed as a git submodule:

```bash
# In the hpc repo
git submodule add https://github.com/mwilde49/10x containers/10x
cd containers/10x && git checkout v1.0.0
cd ../..
git add containers/10x .gitmodules
git commit -m "Add 10x pipeline wrappers submodule"
```

Then use the standard workflow:

```bash
tjp-setup                    # creates config templates
vi /work/$USER/pipelines/cellranger/config.yaml
tjp-launch cellranger        # submits SLURM job
tjp-test cellranger          # smoke test with small data
tjp-test-validate cellranger # verify outputs
```

## Config Examples

### Cell Ranger

```yaml
sample_id: DRG_01
sample_name: DRG_01
fastq_dir: /scratch/juno/user/myproject/fastq
transcriptome: /groups/tprice/pipelines/references/cellranger/refdata-gex-GRCh38-2024-A
localcores: 16
localmem: 120
tool_path: /groups/tprice/software/cellranger
```

### Space Ranger

```yaml
sample_id: VISIUM_01
sample_name: VISIUM_01
fastq_dir: /scratch/juno/user/myproject/fastq
transcriptome: /groups/tprice/pipelines/references/cellranger/refdata-gex-GRCh38-2024-A
image: /scratch/juno/user/myproject/images/tissue.tif
slide: V19L29-096
area: B1
localcores: 16
localmem: 120
tool_path: /groups/tprice/software/spaceranger
```

### Xenium Ranger (resegment)

```yaml
sample_id: XENIUM_01
command: resegment
xenium_bundle: /scratch/juno/user/myproject/xenium_output
localcores: 16
localmem: 120
tool_path: /groups/tprice/software/xeniumranger
```

### Xenium Ranger (import-segmentation)

```yaml
sample_id: XENIUM_01
command: import-segmentation
xenium_bundle: /scratch/juno/user/myproject/xenium_output
segmentation_file: /scratch/juno/user/myproject/segmentation.csv
localcores: 16
localmem: 120
tool_path: /groups/tprice/software/xeniumranger
```

## How It Works

1. The HPC repo's `tjp-launch cellranger` creates a timestamped run directory and snapshots the config
2. The SLURM template calls `bin/cellranger-run.sh <config.yaml> <scratch_output_dir>`
3. The wrapper script reads the YAML, locates the binary, validates paths, and executes
4. 10x tools manage their own threading via `--localcores`/`--localmem`
5. After completion, the SLURM template archives results from scratch to the run directory

## Key Design Decisions

- **No container**: 10x tools bundle their own dependencies and do not containerize well
- **No Nextflow**: 10x tools have their own internal workflow DAG
- **One sample per launch**: Consistent with existing patterns; submit multiple jobs for multiple samples
- **`--exclusive` SLURM**: 10x tools manage own threading and benefit from full node access
- **Wrapper scripts**: Keep SLURM templates clean and allow independent testing

## Versioning

```bash
echo "1.1.0" > VERSION
git add -A && git commit -m "v1.1.0: <describe changes>"
git tag v1.1.0
git push origin main --tags
```
