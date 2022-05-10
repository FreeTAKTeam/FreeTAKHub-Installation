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
wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/test/conda.sh | sudo bash

# install fts virtual environment configuration
wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/test/fts_env.sh | sudo bash
