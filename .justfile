
default:
  @just --list

MY_WD := `pwd`
MY_IPA := `ip -4 addr show docker0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'`
MY_BRANCH := 'issue_118'
NO_COLOR := `TRUE`

alias dbox-act := dbox-activate

dbox-activate:
  -distrobox rm -f fts
  distrobox create --image docker.io/library/ubuntu:22.04 --name fts --yes \
     --init --additional-packages "systemd libpam-systemd pipewire-audio-client-libraries vim snapd"

  distrobox enter --name fts
  sudo snap install just --edge --classic


dbox-install:
  echo "My IPA: {{MY_IPA}}, WD: {{MY_WD}}, ISSUE: {{MY_BRANCH}}"
  sudo bash {{MY_WD}}/scripts/easy_install.sh --repo file://{{MY_WD}}/.git --branch {{MY_BRANCH:-main}} --ip-addr {{MY_IPA}}

