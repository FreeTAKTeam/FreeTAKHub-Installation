#!/usr/bin/env bash
set -x

echo "Downloading package information from configured sources..."
sudo apt -y update

echo "Making sure you have Git installed..."
sudo apt -y install git

echo "Saving current working directory..."
pushd .

echo "Going into your home directory..."
cd ~

echo "Cloning the FreeTAKHub-Installation repository..."
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git

echo "Going into the FreeTAKHub-Installation directory..."
cd FreeTAKHub-Installation

echo "Run the initialization script..."
./init.sh

echo "Run the installation script..."
./install.sh

echo "Going back to your original working directory..."
popd

set +x
