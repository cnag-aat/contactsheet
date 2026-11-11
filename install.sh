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

CONDA_BASE=$(conda info --base 2>/dev/null) || { echo "ERROR: conda not found" >&2; exit 1; }
# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"
CONDA=conda; command -v mamba >/dev/null 2>&1 && CONDA=mamba

if [[ $# -ge 1 ]]; then
    PREFIX=$(realpath -m "$1" 2>/dev/null || python3 -c 'import os,sys;print(os.path.abspath(sys.argv[1]))' "$1")
    TARGET=(-p "$PREFIX")
else
    PREFIX=$CONDA_BASE/envs/contactsheet
    TARGET=(-n contactsheet)
fi
SHARE=$PREFIX/share/contactsheet

if [[ ! -d $PREFIX/conda-meta ]]; then
    echo "creating env $PREFIX"
    $CONDA env create -y "${TARGET[@]}" -f "$YML"
elif ! cmp -s "$YML" "$SHARE/environment.yml"; then
    echo "updating env $PREFIX (environment.yml changed)"
    $CONDA env update "${TARGET[@]}" -f "$YML" --prune
else
    echo "env $PREFIX is up to date"
fi

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
echo "  conda activate ${TARGET[1]}"
echo "  contactsheet ASSEMBLY.fa.gz HIC_READ_DIR [OUTDIR]"
echo "  sbatch $SHARE/contactsheet.sbatch ASSEMBLY.fa.gz HIC_READ_DIR [OUTDIR]"
