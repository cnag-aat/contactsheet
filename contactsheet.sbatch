#!/bin/bash
#SBATCH --job-name=contactsheet
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --output=contactsheet.%j.log
#
# contactsheet.sbatch -- SLURM wrapper for contactsheet
#
#   sbatch contactsheet.sbatch ASSEMBLY.fa[.gz] HIC_READ_DIR [OUTDIR]
#
# Only scheduler resources and environment set-up live here; the pipeline and
# its options (BINSIZE, MAPQ, PLOT_OPTS, ...) are documented in bin/contactsheet.
# Copy this file and adapt the #SBATCH lines to your cluster (add --partition,
# --account, ...), or override them when submitting:
#   sbatch --partition=long --mem=200G contactsheet.sbatch ...
# Pass pipeline options with:
#   sbatch --export=ALL,BINSIZE=10000,PLOT_OPTS="--cmap fall" contactsheet.sbatch ...
#
#   CONDA_ENV   conda env (name or prefix path) activated if contactsheet is not
#               already on PATH  [contactsheet]

set -euo pipefail

if ! command -v contactsheet >/dev/null 2>&1; then
    CONDA_ENV=${CONDA_ENV:-contactsheet}
    CONDA_BASE=$(conda info --base 2>/dev/null) || { echo "ERROR: conda not found" >&2; exit 1; }
    # shellcheck disable=SC1091
    source "$CONDA_BASE/etc/profile.d/conda.sh"
    set +u
    conda activate "$CONDA_ENV" || { echo "ERROR: cannot activate conda env '$CONDA_ENV' (set CONDA_ENV to an env name or prefix path)" >&2; exit 1; }
    set -u
fi

PIPELINE=$(command -v contactsheet || true)
[[ -n $PIPELINE ]] || { echo "ERROR: contactsheet not found in env '${CONDA_ENV:-}' (run install.sh)" >&2; exit 1; }

echo "[$(date '+%F %T')] job ${SLURM_JOB_ID:-local} on $(hostname): $PIPELINE $*"
exec "$PIPELINE" "$@"
