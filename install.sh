#!/bin/bash
#
# install.sh -- create/update the contactsheet conda env and install the scripts
# into it, so they are on PATH once it is activated.
#
#   ./install.sh [ENV_PREFIX]
#
#   e.g. ./install.sh /shared/software/conda/contactsheet   # env at a prefix path
#        ./install.sh                                       # named env "contactsheet"
#
# Re-run after pulling changes: the env is only updated if environment.yml
# changed, and the scripts are always re-copied.
#
# Installs into <env>/bin:                 contactsheet  contactsheet-plot  contactsheet-rename
#          into <env>/share/contactsheet:  contactsheet.sbatch (copy it and adjust the
#                                          #SBATCH resources for your cluster)

set -euo pipefail

SRC=$(dirname "$(realpath "$0")")
YML=$SRC/environment.yml
SCRIPTS=(contactsheet contactsheet-plot contactsheet-rename)
for f in "$YML" "${SCRIPTS[@]/#/$SRC/bin/}" "$SRC/contactsheet.sbatch"; do
    [[ -f $f ]] || { echo "ERROR: $f not found" >&2; exit 1; }
done

die() { echo "ERROR: $*" >&2; exit 1; }

# conda/mamba/micromamba executable; conda is often only a shell function in
# interactive shells, which scripts don't inherit. Override with CONDA=/path/to/conda
find_conda() {
    local c
    for c in "${CONDA:-}" "$(command -v mamba 2>/dev/null)" "$(command -v conda 2>/dev/null)" \
             "${CONDA_EXE:-}" "$(command -v micromamba 2>/dev/null)" "${MAMBA_EXE:-}" \
             "$HOME"/miniforge3/bin/mamba "$HOME"/miniforge3/bin/conda "$HOME"/mambaforge/bin/conda \
             "$HOME"/miniconda3/bin/conda "$HOME"/anaconda3/bin/conda /opt/conda/bin/conda; do
        [[ -n $c && -x $c ]] && { echo "$c"; return 0; }
    done
    return 1
}
CONDA=$(find_conda) || die "no conda, mamba or micromamba found on PATH (or CONDA_EXE/MAMBA_EXE).
  Load it first (e.g. 'module load conda', or 'source ~/miniforge3/etc/profile.d/conda.sh'),
  or point to it: CONDA=/path/to/bin/conda ./install.sh ..."
MICRO=0; [[ $(basename "$CONDA") == micromamba ]] && MICRO=1
echo "using $CONDA"

if [[ $# -ge 1 ]]; then
    PREFIX=$(realpath -m "$1" 2>/dev/null || python3 -c 'import os,sys;print(os.path.abspath(sys.argv[1]))' "$1")
    TARGET=(-p "$PREFIX")
else
    TARGET=(-n contactsheet)
    PREFIX=$("$CONDA" env list 2>/dev/null | awk '$1 == "contactsheet" {print $NF; exit}')
fi

if [[ -z $PREFIX || ! -d $PREFIX/conda-meta ]]; then
    echo "creating env ${TARGET[*]}"
    if (( MICRO )); then "$CONDA" create -y "${TARGET[@]}" -f "$YML"
    else "$CONDA" env create -y "${TARGET[@]}" -f "$YML"; fi
    [[ -n $PREFIX ]] || PREFIX=$("$CONDA" env list 2>/dev/null | awk '$1 == "contactsheet" {print $NF; exit}')
    [[ -d $PREFIX/conda-meta ]] || die "env was not created at '$PREFIX'"
elif ! cmp -s "$YML" "$PREFIX/share/contactsheet/environment.yml"; then
    echo "updating env $PREFIX (environment.yml changed)"
    if (( MICRO )); then "$CONDA" install -y "${TARGET[@]}" -f "$YML"
    else "$CONDA" env update "${TARGET[@]}" -f "$YML" --prune; fi
else
    echo "env $PREFIX is up to date"
fi
SHARE=$PREFIX/share/contactsheet

mkdir -p "$SHARE"
for s in "${SCRIPTS[@]}"; do
    install -m 755 "$SRC/bin/$s" "$PREFIX/bin/$s"
    echo "installed $PREFIX/bin/$s"
done
install -m 644 "$SRC/contactsheet.sbatch" "$YML" "$SHARE/"
echo "installed $SHARE/contactsheet.sbatch"

GIT=$(git -C "$SRC" describe --tags --always --dirty 2>/dev/null || echo unknown)
echo "$GIT" > "$SHARE/VERSION"
echo
echo "done (contactsheet $GIT from $SRC). Use:"
echo "  conda activate $PREFIX"
echo "  contactsheet ASSEMBLY.fa.gz HIC_READ_DIR [OUTDIR]"
echo "  sbatch $SHARE/contactsheet.sbatch ASSEMBLY.fa.gz HIC_READ_DIR [OUTDIR]"
