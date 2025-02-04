#!/usr/bin/env bash
# set -x

echo "Installing Ansible..."
sudo apt-get update
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/ansible-archive-keyring.gpg \
    --keyserver keyserver.ubuntu.com \
    --recv-keys 93C4A3FD7BB9C367

UBUNTU_VERSION=$(lsb_release -cs)
sudo tee /etc/apt/sources.list.d/ansible-ansible.list <<EOF > /dev/null
deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu ${UBUNTU_VERSION} main
EOF

sudo apt-get -y update
sudo apt-get -y install ansible

echo "Add passwordless Terraform and Ansible execution for the current user"
# only add if non-existent
LINE="${USER} ALL=(ALL) NOPASSWD:/usr/bin/ansible-playbook,/usr/bin/terraform"
FILE="/etc/sudoers.d/dont-prompt-${USER}-for-sudo-password"
grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >> "${FILE}"

set +x
