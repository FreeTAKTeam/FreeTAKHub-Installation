#!/usr/bin/env bash
set -x

echo "Install Molecule"
sudo apt update
sudo apt install python3-pip
pip install wheel --upgrade
pip install molecule[lint]

set +x
