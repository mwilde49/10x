# UTDGC589 Cell Ranger Guide — jao230009

This guide walks through running the UTDGC589 samples (589-2, 589-3, 589-4) through Cell Ranger on Juno HPC. Steps 1–2 are performed by maw210003. Steps 3–7 are performed by jao230009.

---

## Step 1 — maw210003: Rsync configs to Juno

Run from the local `10x` repo root:

```bash
rsync -av configs/UTDGC589/jao230009/ maw210003@juno.hpcre.utdallas.edu:/groups/tprice/pipelines/configs/UTDGC589/jao230009/
rsync -av scripts/transfer_UTDGC589_to_jao230009.sh maw210003@juno.hpcre.utdallas.edu:/groups/tprice/pipelines/
```

---

## Step 2 — maw210003: Transfer FASTQs to jao230009's scratch

SSH into Juno as maw210003 and run the transfer script:

```bash
ssh maw210003@juno.hpcre.utdallas.edu
bash /groups/tprice/pipelines/transfer_UTDGC589_to_jao230009.sh
```

You will be prompted for **jao230009's password once**. If the script fails, run manually:

```bash
# Create destination directory (prompts for jao230009's password)
ssh jao230009@localhost "mkdir -p /home/jao230009/scratch/UTDGC589/fastq"

# Transfer all 6 files in one scp call (prompts once)
scp \
    /home/maw210003/scratch/UTDGC589/fastq/589-2_S1_R1_001.fastq.gz \
    /home/maw210003/scratch/UTDGC589/fastq/589-2_S1_R2_001.fastq.gz \
    /home/maw210003/scratch/UTDGC589/fastq/589-3_S2_R1_001.fastq.gz \
    /home/maw210003/scratch/UTDGC589/fastq/589-3_S2_R2_001.fastq.gz \
    /home/maw210003/scratch/UTDGC589/fastq/589-4_S3_R1_001.fastq.gz \
    /home/maw210003/scratch/UTDGC589/fastq/589-4_S3_R2_001.fastq.gz \
    jao230009@localhost:/home/jao230009/scratch/UTDGC589/fastq/
```

---

## Step 3 — jao230009: Log into Juno and run tjp-setup

```bash
ssh jao230009@juno.hpcre.utdallas.edu
tjp-setup
```

---

## Step 4 — jao230009: Create scratch output directory

```bash
mkdir -p /home/jao230009/scratch/UTDGC589/cellranger
```

---

## Step 5 — jao230009: Launch the Cell Ranger jobs

```bash
tjp-launch cellranger --config /groups/tprice/pipelines/configs/UTDGC589/jao230009/589-2.yaml
tjp-launch cellranger --config /groups/tprice/pipelines/configs/UTDGC589/jao230009/589-3.yaml
tjp-launch cellranger --config /groups/tprice/pipelines/configs/UTDGC589/jao230009/589-4.yaml
```

Each command will print a job ID and a log path. Note them down.

---

## Step 6 — jao230009: Monitor jobs

```bash
squeue -u jao230009
```

Jobs start in `PD` (pending) and move to `R` (running) once a node is available. To tail the log for a running job (replace `<JOBID>` and `<TIMESTAMP>`):

```bash
tail -f /work/jao230009/pipelines/cellranger/runs/<TIMESTAMP>/slurm_<JOBID>.out
```

---

## Step 7 — jao230009: Verify success

Once all jobs leave the queue:

```bash
# Check for errors in today's logs
grep -E "ERROR|failed|exit" /work/jao230009/pipelines/cellranger/runs/*/slurm_*.out

# Confirm output files exist for all three samples
ls /home/jao230009/scratch/UTDGC589/cellranger/UTDGC589-{2,3,4}/outs/metrics_summary.csv
```

If `metrics_summary.csv` exists for all three samples, the runs completed successfully.

---

## Reference: Config files

Configs are in shared storage at:

```
/groups/tprice/pipelines/configs/UTDGC589/jao230009/
  589-2.yaml
  589-3.yaml
  589-4.yaml
```

Key settings per sample:

| Field | Value |
|-------|-------|
| `fastq_dir` | `/groups/tprice/data/UTDGC589/fastq` |
| `transcriptome` | `/groups/tprice/pipelines/references/refdata-gex-GRCh38-2024-A` |
| `chemistry` | `threeprime` |
| `localcores` | `16` |
| `localmem` | `64` |
| `create_bam` | `true` |
| `scratch_output_dir` | `/home/jao230009/scratch/UTDGC589/cellranger` |
