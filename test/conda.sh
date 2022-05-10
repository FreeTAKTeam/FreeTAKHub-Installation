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
    rm -f "${_MINICONDA_INSTALLER_FILE-}"
    unset -f _MY_OS
    unset -f _MY_ARCH
    unset -f _USER_HOME
    unset -f _USER_BASHRC
    unset -f _MY_PYTHON_MAJOR_VERSION
    unset -f _MY_PYTHON_MINOR_VERSION
    unset -f _MINICONDA_INSTALLER_INFO
    unset -f _MINICONDA_SHA256SUM
    unset -f _MINICONDA_FILE_URL
    unset -f _MINICONDA_INSTALLER_FILE
}

# check root
if [[ "$EUID" -ne 0 ]]; then
    echo "$0 is not running as root (use sudo)."
    exit 1
fi

_MY_OS="$(uname -s)"
_MY_ARCH="$(uname -m)"
_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
_USER_BASHRC="$_USER_HOME/.bashrc"

while true; do
    case "${1-}" in
    --verbose | -v)
        set -o xtrace
        set -o verbose
        shift
        ;;
    *)
        break
        ;;
    esac
done

# check if system has Python 3 installed
if ! command -v python3 >/dev/null; then
    echo "ERROR: Miniconda requires Python 3.7, 3.8, 3.9 or 3.10." 1>&2
    exit 1
fi

# check for compatible version of Python 3 for miniconda
readonly PYTHON_MAJOR_VERSION=3
readonly PYTHON_MINOR_VERSION_MIN=7
readonly PYTHON_MINOR_VERSION_MAX=10

_MY_PYTHON_MAJOR_VERSION=$(python3 -c 'import sys; print(sys.version_info[:][0])')
if test "$_MY_PYTHON_MAJOR_VERSION" -ne $PYTHON_MAJOR_VERSION; then
    echo "ERROR: Miniconda requires Python 3.7, 3.8, 3.9 or 3.10." 1>&2
    exit 1
fi
_MY_PYTHON_MINOR_VERSION=$(python3 -c 'import sys; print(sys.version_info[:][1])')
if ! ((_MY_PYTHON_MINOR_VERSION >= PYTHON_MINOR_VERSION_MIN && _MY_PYTHON_MINOR_VERSION <= PYTHON_MINOR_VERSION_MAX)); then
    echo "ERROR: Miniconda requires Python 3.7, 3.8, 3.9 or 3.10." 1>&2
    exit 1
fi

# set miniconda python version
# if using Python 3.10, use Python 3.9 installer.
if test "$_MY_PYTHON_MINOR_VERSION" -eq 10; then
    _MY_PYTHON_MINOR_VERSION=9
fi
_MY_PY_VERSION="${_MY_PYTHON_MAJOR_VERSION}${_MY_PYTHON_MINOR_VERSION}"

# get miniconda installer information
readonly MINICONDA_FILE_LIST_URL="https://raw.githubusercontent.com/conda/conda-docs/master/docs/source/miniconda_hashes.rst"

# wget -qnv -O - $MINICONDA_FILE_LIST_URL --> download list of miniconda installer information
# grep -i "py${_MY_PY_VERSION}" --> filter for specific python version
# grep -i "${_MY_OS}-${_MY_ARCH}.sh"  --> filter for specific os and architecture
# head -1 --> get latest by only selecting the first match
# tr -s ' ' --> format line to have one space between tokens
_MINICONDA_INSTALLER_INFO=$(wget -qnv -O - $MINICONDA_FILE_LIST_URL | grep -i "py${_MY_PY_VERSION}" | grep -i "${_MY_OS}-${_MY_ARCH}.sh" | head -1 | tr -s ' ')

# get miniconda installer filename
# cut -d ' ' -f 1 --> get filename
_MINICONDA_FILENAME=$(echo "$_MINICONDA_INSTALLER_INFO" | cut -d ' ' -f 1)
if [ -z "$_MINICONDA_FILENAME" ]; then
    printf "ERROR: Could not find a suitable miniconda installer for your system." 1>&2
    exit 1
fi

# get miniconda installer sha256sum
# cut -d ' ' -f 6 --> get hash
# sed -e "s/\`//g") --> remove backtick marks
_MINICONDA_SHA256SUM=$(echo "$_MINICONDA_INSTALLER_INFO" | cut -d ' ' -f 6 | sed -e "s/\`//g")
if [ -z "$_MINICONDA_SHA256SUM" ]; then
    echo "ERROR: Could not find a suitable miniconda installer for your system." 1>&2
    exit 1
fi

# create temporary file to hold miniconda installer file
_MINICONDA_INSTALLER_FILE=$(mktemp --suffix ".$_MINICONDA_FILENAME")

# download miniconda
readonly MINICONDA_DOWNLOAD_URL="https://repo.anaconda.com/miniconda"
_MINICONDA_FILE_URL="$MINICONDA_DOWNLOAD_URL/$_MINICONDA_FILENAME"
wget -qnv "$_MINICONDA_FILE_URL" -O "$_MINICONDA_INSTALLER_FILE"

# verify file contents with sha256sum
if [ "$(printf "%s %s" "$_MINICONDA_SHA256SUM" "$_MINICONDA_INSTALLER_FILE" | sha256sum --check --status)" = "0" ]; then
    echo "sha256sum check failed." 1>&2
    exit 1
fi

# deactivate any prior environments
if ! [ "${CONDA_SHLVL:-0}" = 0 ]; then
    echo "deactivating ${CONDA_SHLVL} environment(s)..."
    while ! [ "${CONDA_SHLVL:-0}" = 0 ]; do
        if ! conda deactivate; then
            echo "ERROR: failed to deactivate environment(s)" 1>&2
            exit 1
        fi
    done
fi

# install miniconda
readonly CONDA_INSTALL_DIR="/opt/conda"
/bin/bash "$_MINICONDA_INSTALLER_FILE" -bufp "$CONDA_INSTALL_DIR"

# add conda to PATH in bashrc if not existent
readonly CONDA_PATH='PATH=/opt/conda/bin:$PATH'
grep -qxF "$CONDA_PATH" "$_USER_BASHRC" || echo "$CONDA_PATH" >>"$_USER_BASHRC"
export PATH=/opt/conda/bin:$PATH

# source conda.sh in bashrc if not existent
readonly CONDA_SH_CMD='. /opt/conda/etc/profile.d/conda.sh'
grep -qxF "$CONDA_SH_CMD" "$_USER_BASHRC" || echo "$CONDA_SH_CMD" >>"$_USER_BASHRC"
ln -sf /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# clean out unneeded intermediate files
conda clean -tipsy >/dev/null

# configure conda
# don't automatically activate base environment upon login
conda config --set auto_activate_base false
# say yes to everything conda-related
conda config --set always_yes yes
# text indicator in console to show which environment is active
conda config --set changeps1 yes

echo "SUCCESS! Installed conda $(conda --version)."
