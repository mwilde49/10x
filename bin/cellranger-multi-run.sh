#!/usr/bin/env bash
# cellranger-multi-run.sh — translates YAML config into a cellranger multi invocation
#
# Usage: cellranger-multi-run.sh <config.yaml> <scratch_output_dir>
#
# Called by the SLURM template; not invoked directly by users.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/10x_common.sh"

# ── Arguments ────────────────────────────────────────────────────────────────
CONFIG="${1:?Usage: cellranger-multi-run.sh <config.yaml> <scratch_output_dir>}"
SCRATCH_OUTPUT_DIR="${2:?Usage: cellranger-multi-run.sh <config.yaml> <scratch_output_dir>}"

[[ ! -f "$CONFIG" ]] && die "Config file not found: $CONFIG"

# ── Read required fields ─────────────────────────────────────────────────────
require_config_keys "$CONFIG" sample_id localcores localmem

sample_id=$(yaml_get "$CONFIG" "sample_id")
localcores=$(yaml_get "$CONFIG" "localcores")
localmem=$(yaml_get "$CONFIG" "localmem")
tool_path=$(yaml_get "$CONFIG" "tool_path" 2>/dev/null || echo "")

# ── Locate binary ─────────────────────────────────────────────────────────────
CELLRANGER=$(find_10x_binary "cellranger" "$tool_path")
info "Using cellranger: $CELLRANGER"
info "Version: $(get_10x_version "$CELLRANGER")"

# ── Generate multi config CSV via Python ──────────────────────────────────────
MULTI_CSV=$(mktemp /tmp/cellranger_multi_XXXXXX.csv)
trap "rm -f '$MULTI_CSV'" EXIT

python3 - "$CONFIG" "$MULTI_CSV" <<'PYEOF'
import sys, re

config_path, output_csv = sys.argv[1], sys.argv[2]

with open(config_path) as f:
    lines = f.read().splitlines()

def get(key):
    for line in lines:
        m = re.match(r'^\s*' + re.escape(key) + r'\s*:\s*(.+)', line)
        if m:
            return m.group(1).strip().strip('"').strip("'")
    return None

def parse_list(key):
    items, current, in_list = [], {}, False
    for line in lines:
        if re.match(r'^' + re.escape(key) + r'\s*:', line):
            in_list = True
            continue
        if not in_list:
            continue
        stripped = line.rstrip()
        if not stripped:
            continue
        if len(stripped) == len(stripped.lstrip()):
            break
        if re.match(r'^\s*-\s+\S', stripped):
            if current:
                items.append(current)
            current = {}
            m = re.match(r'^\s*-\s+(\S+)\s*:\s*(.*)', stripped)
            if m:
                current[m.group(1)] = m.group(2).strip().strip('"').strip("'")
        else:
            m = re.match(r'^\s+(\S+)\s*:\s*(.*)', stripped)
            if m:
                current[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    if current:
        items.append(current)
    return items

out = []

# [gene-expression]
transcriptome = get('transcriptome')
if not transcriptome:
    print('ERROR: transcriptome is required in config', file=sys.stderr)
    sys.exit(1)
out.append('[gene-expression]')
out.append(f'reference,{transcriptome}')
for yaml_key, csv_key in [
    ('create_bam',      'create-bam'),
    ('chemistry',       'chemistry'),
    ('include_introns', 'include-introns'),
    ('expect_cells',    'expect-cells'),
    ('force_cells',     'force-cells'),
]:
    val = get(yaml_key)
    if val:
        out.append(f'{csv_key},{val}')
out.append('')

# [vdj] (optional)
vdj_ref = get('vdj_reference')
if vdj_ref:
    out.append('[vdj]')
    out.append(f'reference,{vdj_ref}')
    out.append('')

# [feature] (optional)
feat_ref = get('feature_reference')
if feat_ref:
    out.append('[feature]')
    out.append(f'reference,{feat_ref}')
    out.append('')

# [libraries]
libraries = parse_list('libraries')
if not libraries:
    print('ERROR: libraries list is required in config', file=sys.stderr)
    sys.exit(1)
out.append('[libraries]')
out.append('fastq_id,fastqs,feature_types')
for lib in libraries:
    fid   = lib.get('fastq_id', lib.get('sample', ''))
    fqs   = lib.get('fastqs', '')
    ftype = lib.get('feature_types', lib.get('library_type', ''))
    if not all([fid, fqs, ftype]):
        print(f'ERROR: each library entry needs fastq_id, fastqs, and feature_types. Got: {lib}', file=sys.stderr)
        sys.exit(1)
    out.append(f'{fid},{fqs},{ftype}')
out.append('')

# [samples] (CMO multiplexing or Fixed RNA Profiling)
cmo_set = get('cmo_set')
samples = parse_list('samples')
if samples:
    out.append('[samples]')
    if cmo_set:
        out.append(f'cmo-set,{cmo_set}')
    first = samples[0]
    if 'probe_barcode_ids' in first:
        out.append('sample_id,probe_barcode_ids,description')
        for s in samples:
            out.append(f"{s.get('sample_id','')},{s.get('probe_barcode_ids','')},{s.get('description','')}")
    else:
        out.append('sample_id,cmo_ids,description')
        for s in samples:
            out.append(f"{s.get('sample_id','')},{s.get('cmo_ids', s.get('cmos',''))},{s.get('description','')}")
    out.append('')

with open(output_csv, 'w') as f:
    f.write('\n'.join(out) + '\n')
PYEOF

# ── Log and execute ───────────────────────────────────────────────────────────
info "Generated multi config CSV:"
cat "$MULTI_CSV"
info "Sample: $sample_id"
info "Resources: $localcores cores, ${localmem}GB memory"
info "Output dir: $SCRATCH_OUTPUT_DIR"

cd "$SCRATCH_OUTPUT_DIR"

CMD=(
    "$CELLRANGER" multi
    --id="$sample_id"
    --csv="$MULTI_CSV"
    --localcores="$localcores"
    --localmem="$localmem"
)

info "Running: ${CMD[*]}"
"${CMD[@]}"
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    info "cellranger multi completed successfully."
else
    error "cellranger multi failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
