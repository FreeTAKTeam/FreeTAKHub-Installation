#!/usr/bin/env bash
# set -x

# create a key for the user if it doesn't exist
if [[ ! -e /home/${USER}/.ssh/id_rsa.pub ]]; then
    ssh-keygen -t rsa -f "/home/${USER}/.ssh/id_rsa" -N ""
fi

# print key to console
cat /home/${USER}/.ssh/id_rsa.pub

set +x
