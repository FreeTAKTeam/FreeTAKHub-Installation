#!/usr/bin/env bash
echo "Downloading dependencies..."
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt -y update
sudo apt -y install ansible git

echo "Going into your home directory..."
cd ~

echo "Cloning the FreeTAKHub-Installation repository..."
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git

echo "Going into the FreeTAKHub-Installation directory..."
cd FreeTAKHub-Installation

echo "Adding passwordless Ansible execution for the current user..."
# only add if non-existent
LINE="$USER ALL=(ALL) NOPASSWD:/usr/bin/ansible-playbook,/usr/bin/terraform"
FILE="/etc/sudoers.d/dont-prompt-$USER-for-sudo-password"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

echo "Creating a public/private key pair for the user if it doesn't exist..."
if [[ ! -e /home/$USER/.ssh/id_rsa.pub ]]; then
    ssh-keygen -t rsa -f "/home/$USER/.ssh/id_rsa" -N ""
fi

echo "Running Ansible Playbook..."
ansible-playbook -u root -i localhost, --connection=local install_all.yml
