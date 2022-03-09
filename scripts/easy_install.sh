#!/usr/bin/env bash

echo "Downloading dependencies..."
sudo apt -y update
sudo apt -y software-properties-common
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt -y install ansible git

echo "Going into your home directory..."
cd ~

if [ ! -d ~/FreeTAKHub-Installation ]
then
    echo "Cloning the FreeTAKHub-Installation repository..."
    git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
    cd FreeTAKHub-Installation
else
    echo "Pulling latest from the FreeTAKHub-Installation repository..."
    cd FreeTAKHub-Installation
    git pull
fi

echo "Adding passwordless Ansible execution for the current user..."
# only add if non-existent
LINE="${USER} ALL=(ALL) NOPASSWD:/usr/bin/ansible-playbook,/usr/bin/terraform"
FILE="/etc/sudoers.d/dont-prompt-${USER}-for-sudo-password"
grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

echo "Creating a public/private key pair for the user if it doesn't exist..."
if [[ ! -e ${HOME}/.ssh/id_rsa.pub ]]; then
    ssh-keygen -t rsa -f "${HOME}/.ssh/id_rsa" -N ""
fi

echo "Running Ansible Playbook..."
ansible-playbook -u root -i localhost, --connection=local install_all.yml
