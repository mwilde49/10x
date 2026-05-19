# cellranger multi — Complete Usage Guide

`cellranger multi` is used when a sample has more than one library type, or when multiple samples are pooled in a single capture. This wrapper translates a YAML config into the Cell Ranger multi CSV format and submits it to the cluster.

Use `cellranger count` (the standard pipeline) for simple single-library GEX runs.
Use `cellranger multi` for any of the cases below.

---

## How it works

The wrapper reads your YAML config, generates a Cell Ranger multi CSV internally, and passes it to `cellranger multi`. You never write the CSV by hand.

---

## Common fields (all use cases)

These appear in every config:

```yaml
sample_id: my_sample              # output directory name
localcores: 16
localmem: 64
scratch_output_dir: /path/to/output
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true                  # required for Cell Ranger 10.0.0+
```

---

## Library types

The `feature_types` field in each library entry must be one of:

| Value | Use case |
|-------|----------|
| `Gene Expression` | Standard GEX |
| `VDJ-T` | T cell receptor |
| `VDJ-T-GD` | Gamma-delta T cell receptor |
| `VDJ-B` | B cell receptor |
| `Antibody Capture` | CITE-seq / protein panels |
| `CRISPR Guide Capture` | CRISPR screens |
| `Multiplexing Capture` | CellPlex (CMO-based sample multiplexing) |
| `Fixed RNA Profiling` | Flex / fixed RNA |

---

## Use case examples

### 1. GEX only (single library)

Use `cellranger count` instead unless you specifically need `multi` features.
If you do need multi for a single GEX library:

```yaml
sample_id: my_gex_sample
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true
chemistry: threeprime

libraries:
  - fastq_id: my_sample
    fastqs: /path/to/fastqs
    feature_types: Gene Expression
```

---

### 2. GEX + VDJ-T (T cell immune profiling)

```yaml
sample_id: my_tcell_sample
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true
vdj_reference: /groups/tprice/pipelines/references/refdata-cellranger-vdj-GRCh38-alts-ensembl-7.1.0

libraries:
  - fastq_id: my_sample_gex
    fastqs: /path/to/gex/fastqs
    feature_types: Gene Expression
  - fastq_id: my_sample_vdj
    fastqs: /path/to/vdj/fastqs
    feature_types: VDJ-T
```

---

### 3. GEX + VDJ-B (B cell immune profiling)

Same as VDJ-T, change `feature_types` to `VDJ-B`:

```yaml
sample_id: my_bcell_sample
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true
vdj_reference: /groups/tprice/pipelines/references/refdata-cellranger-vdj-GRCh38-alts-ensembl-7.1.0

libraries:
  - fastq_id: my_sample_gex
    fastqs: /path/to/gex/fastqs
    feature_types: Gene Expression
  - fastq_id: my_sample_vdj
    fastqs: /path/to/vdj/fastqs
    feature_types: VDJ-B
```

---

### 4. GEX + Antibody Capture (CITE-seq)

Requires a feature reference CSV listing the antibody panel.

```yaml
sample_id: my_citeseq_sample
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true
feature_reference: /path/to/antibody_panel.csv

libraries:
  - fastq_id: my_sample_gex
    fastqs: /path/to/gex/fastqs
    feature_types: Gene Expression
  - fastq_id: my_sample_ab
    fastqs: /path/to/antibody/fastqs
    feature_types: Antibody Capture
```

---

### 5. GEX + CRISPR Guide Capture

Requires a feature reference CSV listing the guide library.

```yaml
sample_id: my_crispr_sample
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true
feature_reference: /path/to/crispr_guide_ref.csv

libraries:
  - fastq_id: my_sample_gex
    fastqs: /path/to/gex/fastqs
    feature_types: Gene Expression
  - fastq_id: my_sample_crispr
    fastqs: /path/to/crispr/fastqs
    feature_types: CRISPR Guide Capture
```

---

### 6. Cell Multiplexing — CellPlex (CMO-based)

Multiple samples pooled in one capture, demultiplexed by Cell Multiplexing Oligos.

```yaml
sample_id: my_cellplex_run
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true

libraries:
  - fastq_id: my_run_gex
    fastqs: /path/to/gex/fastqs
    feature_types: Gene Expression
  - fastq_id: my_run_cmo
    fastqs: /path/to/cmo/fastqs
    feature_types: Multiplexing Capture

samples:
  - sample_id: sampleA
    cmo_ids: CMO301
    description: Patient A
  - sample_id: sampleB
    cmo_ids: CMO302
    description: Patient B
  - sample_id: sampleC
    cmo_ids: CMO303
    description: Patient C
```

---

### 7. Fixed RNA Profiling (Flex)

Samples multiplexed using probe barcodes instead of CMOs.

```yaml
sample_id: my_flex_run
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true

libraries:
  - fastq_id: my_flex_library
    fastqs: /path/to/fastqs
    feature_types: Fixed RNA Profiling

samples:
  - sample_id: sampleA
    probe_barcode_ids: BC001
    description: Sample A
  - sample_id: sampleB
    probe_barcode_ids: BC002
    description: Sample B
```

---

### 8. GEX + VDJ-T + Antibody Capture (combined immune profiling)

```yaml
sample_id: my_multimodal_sample
localcores: 16
localmem: 64
scratch_output_dir: /home/maw210003/scratch/my_project/cellranger
transcriptome: /groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A
create_bam: true
vdj_reference: /groups/tprice/pipelines/references/refdata-cellranger-vdj-GRCh38-alts-ensembl-7.1.0
feature_reference: /path/to/antibody_panel.csv

libraries:
  - fastq_id: my_sample_gex
    fastqs: /path/to/gex/fastqs
    feature_types: Gene Expression
  - fastq_id: my_sample_vdj
    fastqs: /path/to/vdj/fastqs
    feature_types: VDJ-T
  - fastq_id: my_sample_ab
    fastqs: /path/to/antibody/fastqs
    feature_types: Antibody Capture
```

---

## Launching on Juno

```bash
tjp-launch cellranger-multi --config /groups/tprice/pipelines/configs/<project>/<sample>.yaml
```

Monitor:
```bash
squeue -u $USER
```

Verify success:
```bash
ls /path/to/scratch_output_dir/<sample_id>/outs/
```

A successful run produces `per_sample_outs/` (for multiplexed runs) or `outs/` (for single-sample runs).

---

## Optional config fields

| Field | Description |
|-------|-------------|
| `chemistry` | Override chemistry detection (e.g., `SC3Pv3`, `auto`) |
| `include_introns` | Include intronic reads (`true`/`false`) |
| `expect_cells` | Expected cell count hint |
| `force_cells` | Force a specific cell count |
| `tool_path` | Override the Cell Ranger binary location |
| `vdj_reference` | Path to VDJ reference (required for VDJ libraries) |
| `feature_reference` | Path to feature reference CSV (required for Antibody Capture / CRISPR) |
| `cmo_set` | Custom CMO set CSV (optional, CellPlex only) |
