#!/usr/bin/env bash
set -x

if [[ ! -e /home/$USER/.ssh/id_rsa.pub ]]; then
    ssh-keygen -t rsa -f "/home/$USER/.ssh/id_rsa" -N ""
fi

cat /home/$USER/.ssh/id_rsa.pub

set +x
