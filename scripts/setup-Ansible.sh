#!/bin/bash
set -x

echo "Installing Ansible..."
sudo apt update
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt -y update
sudo apt -y install ansible

# allow current user to run Ansible and Terraform without sudo
echo "$USER  ALL=(ALL) NOPASSWD:/usr/bin/ansible-playbook,/usr/bin/terraform" | sudo tee /etc/sudoers.d/$USER

set +x
