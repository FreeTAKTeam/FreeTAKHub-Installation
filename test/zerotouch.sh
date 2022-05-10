#!/usr/bin/env bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# set failfast
set -o errexit
set -o nounset
set -o pipefail
shopt -s inherit_errexit

trap cleanup SIGINT SIGQUIT SIGTERM SIGTSTP ERR EXIT

cleanup() {
    rm -rf "$_FTS_ENV_FILE"
    unset _USER_HOME
    unset _USER_BASHRC
}

# check root
if [[ "$EUID" -ne 0 ]]; then
    echo "$0 is not running as root (use sudo)."
    exit 1
fi

while true; do
    case "${1-}" in
    --verbose | -v)
        set -o xtrace
        set -o verbose
        VERBOSITY_FLAG=-v
        shift
        ;;
    *)
        break
        ;;
    esac
done

# install conda virtual environment
# wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/test/conda.sh | sudo bash
# sudo bash ./conda.sh $VERBOSITY_FLAG

# # activate base environment
# eval "$(conda shell.bash hook)" >/dev/null
# conda info
# echo "Activating base environment..."
# if ! conda activate base >/dev/null; then
#     echo "ERROR: failed to activate base environment" 1>&2
#     exit 1
# fi

# user variables
_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
_USER_BASHRC="$_USER_HOME/.bashrc"

# add command to bashrc to auto activate environment
readonly CONDA_ACTIVATE_CMD="conda activate fts"
grep -qxF "$CONDA_ACTIVATE_CMD" "$_USER_BASHRC" || echo "$CONDA_ACTIVATE_CMD" >>"$_USER_BASHRC"
source "$_USER_BASHRC"

# create fts virtual environment
readonly ENV_NAME="fts"
readonly PYTHON_ENV_VERSION=3.8
conda create --yes --name "$ENV_NAME" python="$PYTHON_ENV_VERSION"

# download fts environment
_FTS_ENV_FILE=$(mktemp --suffix ".environment.yml")
readonly _FTS_ENV_URL="https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/test/environment.yml"
wget -qnv "$_MINICONDA_FILE_URL" -O "$_FTS_ENV_FILE"

# verify file contents with sha256sum
readonly _FTS_ENV_SHASUM="36d751d9c8bb6d0aed87c3873ccf2e79604c0ed18cd34d283c4027e834e5150c"
if [ "$(printf "%s %s" "$_FTS_ENV_SHASUM" "$_FTS_ENV_FILE" | sha256sum --check --status)" = "0" ]; then
    echo "sha256sum check failed." 1>&2
    exit 1
fi

# install fts environment
conda env update -n "$ENV_NAME" --file "$_FTS_ENV_FILE"

# initialize shell environment
# detect shell
if [ -n "$BASH_VERSION" ]; then
    conda init bash
elif [ -n "$ZSH_VERSION" ]; then
    conda init zsh
else
    echo "ERROR: unidentified shell: $SHELL" 1>&2
fi

# activate fts virtual environment
eval "$(conda shell.bash hook)"
conda info
if ! conda activate $ENV_NAME >/dev/null; then
    echo "Error: failed to activate fts environment"
    exit 1
fi

echo "Activated fts environment"
conda info
