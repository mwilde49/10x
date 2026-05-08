#!/usr/bin/env bash
# transfer_bcl_to_juno.sh — rsync a BCL run folder to Juno HPC
#
# Usage: bash scripts/transfer_bcl_to_juno.sh

set -euo pipefail

# ── Prompts ───────────────────────────────────────────────────────────────────
read -rp "Juno username: " JUNO_USER
read -rp "Project name (e.g. UTDGC583): " PROJECT
read -rp "Path to BCL run folder: " SRC
SRC="${SRC%/}"    # strip trailing slash if present

JUNO_HOST="juno.hpcre.utdallas.edu"

# Derive run folder name and destination from inputs
RUN_FOLDER="$(basename "$SRC")"
DEST_BASE="/work/${JUNO_USER}/projects/${PROJECT}/raw"
DEST="${DEST_BASE}/${RUN_FOLDER}"

# ── Pre-flight ────────────────────────────────────────────────────────────────
if [[ ! -d "$SRC" ]]; then
    echo "ERROR: Source directory not found: $SRC"
    exit 1
fi

echo "========================================================"
echo "  BCL Transfer → Juno HPC"
echo "========================================================"
echo "  From : $SRC"
echo "  To   : ${JUNO_USER}@${JUNO_HOST}:${DEST}"
echo ""

# Create destination directory on Juno
ssh "${JUNO_USER}@${JUNO_HOST}" "mkdir -p '${DEST}'"

# ── Transfer ──────────────────────────────────────────────────────────────────
# --checksum      : compare by checksum, not just size/mtime (NTFS mtimes unreliable)
# --partial       : keep partial files so interrupted transfers can resume
# --no-perms      : don't copy Windows NTFS permissions (let Juno umask apply)
# --exclude       : skip macOS metadata noise
rsync -a \
    --checksum \
    --partial \
    --progress \
    --no-perms \
    --exclude='.DS_Store' \
    "${SRC}/" \
    "${JUNO_USER}@${JUNO_HOST}:${DEST}/"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "Verifying transfer integrity..."
DIFF=$(rsync -a --checksum --dry-run --no-perms --exclude='.DS_Store' \
    "${SRC}/" "${JUNO_USER}@${JUNO_HOST}:${DEST}/" 2>&1)

if [[ -z "$DIFF" ]]; then
    echo "  Verification PASSED — source and destination match."
else
    echo "  WARNING: Verification found differences:"
    echo "$DIFF"
    exit 1
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "  Transfer complete. Use these paths in your configs:"
echo ""
echo "  mkfastq config:"
echo "    run_dir: ${DEST}"
echo "    samplesheet: ${DEST}/SampleSheet.csv"
echo "========================================================"
