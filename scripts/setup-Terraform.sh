#!/usr/bin/env bash
# set -x

echo "Installing Terraform..."
sudo apt-get update
sudo apt-get install -y gnupg curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

UBUNTU_VERSION=$(lsb_release -cs)
sudo tee /etc/apt/sources.list.d/hashicorp.list <<EOF  > /dev/null
deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg arch=amd64] https://apt.releases.hashicorp.com $(UBUNTU_VERSION) main
EOF

sudo apt-get update
sudo apt-get install terraform

set +x
