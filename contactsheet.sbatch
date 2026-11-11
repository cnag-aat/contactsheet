#!/bin/bash
#SBATCH --job-name=contactsheet
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=32
#SBATCH --mem=128G
#SBATCH --output=contactsheet.%j.log
#
# contactsheet.sbatch -- SLURM wrapper for contactsheet
#
#   conda activate contactsheet          # or: conda activate /path/to/env
#   sbatch contactsheet.sbatch ASSEMBLY.fa[.gz] HIC_READ_DIR [OUTDIR]
#
# Activate the env before submitting: sbatch passes your PATH on to the job
# (with --export, always start with ALL: --export=ALL,VAR=...).
# Only scheduler resources live here; the pipeline and its options (BINSIZE,
# MAPQ, PLOT_OPTS, ...) are documented in bin/contactsheet.
# Copy this file and adapt the #SBATCH lines to your cluster (add --partition,
# --account, ...), or override them when submitting:
#   sbatch --partition=long --mem=200G contactsheet.sbatch ...
# Pass pipeline options with:
#   sbatch --export=ALL,BINSIZE=10000,PLOT_OPTS="--cmap fall" contactsheet.sbatch ...
#
#   CONDA_ENV   env prefix path, used only if contactsheet is not on PATH
#               (e.g. when submitting with --export=NONE)

set -euo pipefail

if ! command -v contactsheet >/dev/null 2>&1; then
    if [[ -n ${CONDA_ENV:-} && -x $CONDA_ENV/bin/contactsheet ]]; then
        export PATH=$CONDA_ENV/bin:$PATH CONDA_PREFIX=$CONDA_ENV
    else
        echo "ERROR: contactsheet is not on PATH. Activate its conda env before submitting:" >&2
        echo "  conda activate /path/to/contactsheet/env" >&2
        echo "  sbatch contactsheet.sbatch ASSEMBLY.fa.gz HIC_READ_DIR [OUTDIR]" >&2
        echo "If it was activated: pass options with --export=ALL,VAR=..., not --export=VAR=..." >&2
        echo "(without ALL, SLURM passes only the variables named, so the env's PATH is lost)" >&2
        case ${SLURM_EXPORT_ENV:-ALL} in
            ALL*|all*) ;;
            *) echo "This job was submitted with --export=$SLURM_EXPORT_ENV" >&2 ;;
        esac
        [[ -n ${CONDA_ENV:-} ]] && echo "(CONDA_ENV='$CONDA_ENV' has no bin/contactsheet: run install.sh into it)" >&2
        exit 1
    fi
fi

PIPELINE=$(command -v contactsheet)
echo "[$(date '+%F %T')] job ${SLURM_JOB_ID:-local} on $(hostname): $PIPELINE $*"
exec "$PIPELINE" "$@"
