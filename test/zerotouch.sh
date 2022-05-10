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
    rm -f "${_FTS_ENV_FILE:-0}"
    rm -f "${_MINICONDA_INSTALLER_FILE:-0}"
    unset -f _MY_OS
    unset -f _MY_ARCH
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

while true; do
    case "${1-}" in
    --verbose | -v)
        set -o xtrace
        # set -o verbose
        VERBOSITY_FLAG=-v
        shift
        ;;
    *)
        break
        ;;
    esac
done

# user variables
_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
USER_BASHRC="$_USER_HOME/.bashrc"
export _USER_HOME
export USER_BASHRC

# install conda virtual environment
wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/test/conda.sh | sudo -E bash
# sudo -E bash conda.sh -v

# install fts virtual environment configuration
wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/test/fts_env.sh | sudo -E bash
# sudo -E bash fts_env.sh -v
