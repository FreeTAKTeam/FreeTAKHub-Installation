#!/usr/bin/env bash
# set -x

echo "Installing Docker.."
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg lsb-release
sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

echo "Adding current user to docker group"
sudo groupadd docker
sudo usermod -aG docker ${USER}
sudo chown ${USER} /var/run/docker.sock

echo "Enabling Docker services"
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

set +x
