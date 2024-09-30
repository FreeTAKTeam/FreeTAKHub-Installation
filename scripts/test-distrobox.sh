#!/bin/bash

# cd ./Projects/fts-install 


distrobox create --image docker.io/library/ubuntu:22.04 --name fts --yes \
  --init --additional-packages "systemd libpam-systemd pipewire-audio-client-libraries" 

distrobox enter --name fts
