#!/usr/bin/env bash
# set -x

echo "Installing Virtual Environment"
sudo apt-get update
sudo apt-get install -y python3-pip python${PY3_VER}-venv python3-setuptools

python${PY3_VER} -m venv $HOME/.env
source $HOME/.env/bin/activate
python${PY3_VER} -m pip install --upgrade pip

echo "Adding 'activate' command for executing the virtual environment"
# only add if non-existent
LINE="alias activate=\". $HOME/.env/bin/activate\""
FILE="$HOME/.bashrc"
grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

set +x
