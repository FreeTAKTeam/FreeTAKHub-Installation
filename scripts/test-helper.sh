#!/bin/bash

cd ./Projects/fts-install
export MY_WD=$(pwd)
export MY_IPA=$(ip -4 addr show docker0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
export MY_BRANCH=issue_118
export NO_COLOR=TRUE

echo "My IPA: ${MY_IPA}, WD: ${MY_WD}, ISSUE: ${MY_BRANCH}"
sudo bash ${MY_WD}/scripts/easy_install.sh --repo file://${MY_WD}/.git --branch ${MY_BRANCH:-main} --ip-addr ${MY_IPA}
