#!/bin/bash
set -x

ansible-playbook -u ansible_user_id -i localhost, --connection=local install_all.yml -K

set +x
