#!/usr/bin/env bash
# Run this script on Juno as maw210003.
# Transfers UTDGC589 FASTQs directly to jao230009's scratch directory.
# You will be prompted for jao230009's password once.

set -euo pipefail

SRC="/home/maw210003/scratch/UTDGC589/fastq"
DEST_USER="jao230009"
DEST_HOST="localhost"
DEST_DIR="/home/${DEST_USER}/scratch/UTDGC589/fastq"
CTRL="/tmp/ssh_ctrl_${DEST_USER}_$$"

echo "============================================================"
echo "  UTDGC589 FASTQ Transfer: maw210003 -> jao230009"
echo "============================================================"
echo ""
echo "Destination: ${DEST_USER}@${DEST_HOST}:${DEST_DIR}"
echo ""
echo "You will be prompted for jao230009's password."
echo ""

# Open a persistent connection (single password prompt) and create destination dir
ssh -M -S "$CTRL" -o ControlPersist=300s "${DEST_USER}@${DEST_HOST}" \
    "mkdir -p ${DEST_DIR}"

echo "[1/1] Transferring FASTQs..."
scp -o ControlPath="$CTRL" \
    "$SRC/589-2_S1_R1_001.fastq.gz" \
    "$SRC/589-2_S1_R2_001.fastq.gz" \
    "$SRC/589-3_S2_R1_001.fastq.gz" \
    "$SRC/589-3_S2_R2_001.fastq.gz" \
    "$SRC/589-4_S3_R1_001.fastq.gz" \
    "$SRC/589-4_S3_R2_001.fastq.gz" \
    "${DEST_USER}@${DEST_HOST}:${DEST_DIR}/"

ssh -S "$CTRL" -O exit "${DEST_USER}@${DEST_HOST}" 2>/dev/null || true

echo ""
echo "Transfer complete."
echo "Configs are already in shared storage at:"
echo "  /groups/tprice/pipelines/configs/UTDGC589/jao230009/"
