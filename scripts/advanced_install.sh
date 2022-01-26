#!/usr/bin/env bash

echo "Downloading dependencies..."
sudo apt-add-repository -y ppa:ansible/ansible
sudo apt -y update
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

echo "Creating a public/private key pair for the user if it doesn't exist..."
if [[ ! -e ${HOME}/.ssh/id_rsa.pub ]]; then
    ssh-keygen -t rsa -f "${HOME}/.ssh/id_rsa" -N ""
fi

read -p "Install FreeTAKServer (y/n)? (default: y) : " response </dev/tty
INSTALL_MAINSERVER=${response:-y}

if [ "${INSTALL_MAINSERVER}" == "y" ] ; then
    ansible-playbook -u root -i localhost, --connection=local install_mainserver.yml
fi

read -p "Install Video Server (y/n)? (default: y): " response </dev/tty
INSTALL_VIDEOSERVER=${response:-y}

if [ "${INSTALL_VIDEOSERVER}" == "y" ] ; then
    ansible-playbook -u root -i localhost, --connection=local install_videoserver.yml
fi

read -p "Install Node-RED Server (y/n)? (default: y): " response </dev/tty
INSTALL_NODEREDSERVER=${response:-y}

if [ "${INSTALL_NODEREDSERVER}" == "y" ] ; then
    ansible-playbook -u root -i localhost, --connection=local install_noderedserver.yml
fi