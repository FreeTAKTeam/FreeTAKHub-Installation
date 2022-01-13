#!/bin/bash
set -x

ansible-playbook -i localhost, --connection=local install_all.yml

set +x
