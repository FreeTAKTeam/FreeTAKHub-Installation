#!/bin/bash
set -x

ansible-playbook -u root -i localhost, --connection=local install_all.yml -K

set +x
