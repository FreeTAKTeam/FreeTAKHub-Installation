#!/usr/bin/env bash
# set -x

ansible-playbook -u root -i localhost, --connection=local ./install_all.yml

set +x
