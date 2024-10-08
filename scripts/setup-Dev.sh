#!/usr/bin/env bash
# set -x

echo "Installing development packages"
sudo apt-get update
sudo apt-get install -y git vim

echo "Installing development environment"
source setup-Virtual-Env.sh
source setup-Ansible.sh
source setup-Molecule.sh
source setup-Terraform.sh
source setup-Docker.sh
source setup-Keys.sh

set +x
