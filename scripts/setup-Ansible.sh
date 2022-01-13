#!/bin/bash
set -x

echo "Installing Ansible..."
sudo apt update
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt -y update
sudo apt -y install ansible

echo: "Add passwordless Terraform and Ansible execution for the current user"
# only add if non-existent
LINE="$USER ALL=(ALL) NOPASSWD:/usr/bin/ansible-playbook,/usr/bin/terraform"
FILE="/etc/sudoers.d/dont-prompt-$USER-for-sudo-password"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

set +x
