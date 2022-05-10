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
    :
}

# check root
if [[ "$EUID" -ne 0 ]]; then
    echo "$0 is not running as root (use sudo)."
    exit 1
fi

wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/test/conda.sh | sudo bash

#test
