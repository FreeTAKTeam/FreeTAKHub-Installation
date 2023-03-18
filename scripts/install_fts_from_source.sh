#!/bin/bash
echo $1
fts_remote=https://github.com/FreeTAKTeam/FreeTakServer.git
fts_path=$HOME/FreeTakServer
branch="v2.0.17b0"
pushd $HOME
[[ -d $fts_path ]] || git clone $fts_remote
pushd $fts_path
git pull
git switch $branch
pip3 install .
[[ $? -eq 0 ]] && r="SUCCESS" || r="Errors encountered"
popd

echo
echo
echo "$r"
