#!/usr/bin/env bash

# check if user is root
if [[ "$EUID" -ne 0 ]]; then
  printf "$0 is not running as root (use sudo).\n"
  exit 1
fi

# save the time started to calculate install time
start=$(date +%s) || false

# set failfast
set -o errexit

############################################################ MAIN BUSINESS LOGIC

main() {

  identify_system
  setup_virtual_environment
  install_components
  start_services

  end=$(date +%s)
  total_seconds=$((end - start))
  printf "SUCCESS! INSTALLED IN %ss.\n" "$total_seconds"

}

readonly user_exec="sudo -i -u $SUDO_USER"
readonly unit_files_dir="/lib/systemd/system"
readonly fts_install_repo="FreeTAKHub-Installation"
readonly fts_repo="FreeTakServer"
readonly base_repo="https://github.com/FreeTAKTeam"
readonly group_name="fts"
readonly env_name="fts"
readonly python_version="3.8"
readonly fts_package="FreeTAKServer"
readonly fts_service=fts
readonly fts_ui_package="FreeTAKServer-UI"
readonly fts_ui_service=fts-ui
readonly webmap_name="FTH-webmap-linux"
readonly webmap_version="0.2.5"
readonly webmap_filename="$webmap_name-$webmap_version.zip"
readonly webmap_executable="$webmap_name-$webmap_version"
readonly webmap_url="https://github.com/FreeTAKTeam/FreeTAKHub/releases/download/v$webmap_version/$webmap_name-$webmap_version.zip"
readonly webmap_sha256="11afcde545cc4c2119c0ff7c89d23ebff286c99c6e0dfd214eae6e16760d6723"
readonly webmap_install_dir="/usr/local/bin"
readonly webmap_config="webMAP_config.json"
readonly webmap_service=webmap

SYSTEM_NAME=$(uname)
SYSTEM_DIST="Unknown"
SYSTEM_DIST_BASED_ON="Unknown"
SYSTEM_PSEUDO_NAME="Unknown"
SYSTEM_VERSION="Unknown"
SYSTEM_ARCH=$(uname -m)
SYSTEM_ARCH_NAME="Unknown"
SYSTEM_KERNEL=$(uname -r)
SYSTEM_CONTAINER=false
CLOUD_PROVIDER=false

trap cleanup SIGINT SIGTERM

cleanup() {
  rm -f "$conda_installer"
  rm -f "$webmap_zip"
}

# override localization settings to ensure English output
export LC_ALL=C

# home directory of user running this script
user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6) || false

# unless specified, default target IPv4 is localhost
my_ipv4="127.0.0.1"
fts_ip=$my_ipv4
fts_ui_ip=$my_ipv4
webmap_ip=$my_ipv4

no_color="0"
COLOR_BOLD="\033[1m"
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_OFF="\033[0m"


declare -a supported_os=(
  "ubuntu 20.04"
)

usage() {
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]:-}") [<optional-arguments>]

Install Free TAK Server and components.

Available options:
-h, --help          print help
-v, --verbose       print script debug info
-l, --log           log output to file named fts.log (in running directory)
    --no-color      turn off console colors

===============================================================================
INSTALLATION OPTIONS
===============================================================================
The default installation is the fts core installation, which consists of:
    1. fts
    2. ui
    3. webmap

Installation of other components requires passing parameters to the command.

-a, --ansible       install using ansible

If any of the below switches are set, only the specified component will be
installed.

    --all           install all components (default is only fts, ui & webmap)
    --fts           install fts
    --ui            install fts user interface
    --map           install webmap
    --nodered       install node-red server
    --video         install video server
    --mumble        install murmur server voip and mumble client

===============================================================================
NETWORKING OPTIONS
===============================================================================
If none of the below options are set, the IPv4 will be localhost.

  -i, --ipv4=IPV4   If set, all services installed will use this IPv4.

If you would like to use specific IPs for components, use the options below:

    --fts_ip=IPV4   Set fts ipv4, defaults to localhost.
    --map_ip=IPV4   Set webmap ipv4, defaults to localhost.

===============================================================================
EXAMPLES
===============================================================================
Install freetakserver (fts) core components fts, user interface, and webmap:

        sudo ./easy_install

Install all components (fts, ui, webmap, video server, mumble/murmur voip):

        sudo ./easy_install --all

Install using a specific ipv4:

        sudo ./easy_install --ipv4 209.85.231.104

Install fts core components with log and verbosity:

        sudo ./easy_install -v -l

Install all components only the video server:

        sudo ./easy_install --video

USAGE_TEXT
  exit 1
}

####################################################################### LOGGING

# main logging functions


print_error() {
  {
    printf "$COLOR_RED"
    printf "ERROR: "
    printf "$COLOR_OFF"
    printf '%s\n' "$@"
  } >&2
}

print_warn() {
  printf "$COLOR_YELLOW"
  printf "WARN: "
  printf "$COLOR_OFF"
  printf '%s\n' "$@"
}

print_info() {
  printf "$COLOR_BLUE"
  printf "INFO: "
  printf "$COLOR_OFF"
  printf '%s\n' "$@"
}

print_success() {
  printf "$COLOR_GREEN"
  printf "SUCCESS: "
  printf "$COLOR_OFF"
  printf '%s\n' "$@"
}

print_bold() {
  printf "$COLOR_BOLD"
  printf '%b\n' "$@"
  printf "$COLOR_OFF"
}

print_msg() {
  printf '%s\n' "$@"
}

setup_log() {
  exec > >(tee fts.log) 2>&1
}

validate_ipv4() {
  # check if $candidate_ip is a valid my_ipv4 address
  # return 0 if true, 1 otherwise
  local arr element candidate_ip="$1"
  IFS=. read -r -a arr <<<"$candidate_ip"
  [[ ${#arr[@]} != 4 ]] && return 1
  for element in "${arr[@]}"; do
    [[ (! $element =~ ^[0-9]+$) || $element =~ ^0[1-9]+$ ]] && return 1
    ((element < 0 || element > 255)) && return 1
  done
  return 0
}

check_ipv4_arg() {
  local candidate_ipv4=$1
  set +e # don't failfast when validating
  result="$(validate_ipv4 $candidate_ipv4)"
  set -e # turn on failfast
  if [[ ("$result" -eq "0") ]]; then
    print_error "INVALID IPv4" "$candidate_ipv4"
    exit 1
  fi
}

# parse arguments

parse_args() {

  while true; do
    case "${1-}" in
    --help | -h)
      usage
      exit 0
      shift
      ;;
    --no-color)
      no_color=1
      shift
      ;;
    --log | -l)
      setup_log
      shift
      ;;
    --verbose | -v)
      # set -x
      shift
      ;;
    *)
      break
      ;;
    esac
  done

  if [ -z $no_color ]; then
    unset COLOR_BOLD
    unset COLOR_RED
    unset COLOR_GREEN
    unset COLOR_YELLOW
    unset COLOR_BLUE
    unset COLOR_OFF
  fi

  # parse arguments
  while true; do
    case "${1-}" in
    --ansible | -a)
      use_ansible=1
      shift
      ;;
    --ipv4)
      candidate_ipv4=$2
      check_ipv4_arg "$candidate_ipv4"
      my_ipv4="$candidate_ipv4"
      shift
      shift
      ;;
    --fts_ip)
      candidate_ipv4=$2
      check_ipv4_arg "$candidate_ipv4"
      fts_ip="$candidate_ipv4"
      shift
      shift
      ;;
    --map_ip)
      candidate_ipv4=$2
      check_ipv4_arg "$candidate_ipv4"
      webmap_ip="$candidate_ipv4"
      shift
      shift
      ;;
    -?*)
      "FAIL: unknown option $1"
      exit 1
      ;;
    *)
      break
      ;;
    esac
  done

  print_info "IPv4 ADDRESS=$my_ipv4"

}

replace() {
  # global replacement of string in file
  local file=$1 search=$2 replace=$3
  print_info "attempting to replace string: $search"
  print_info "    with string: $replace"
  print_info "    in file: $file"
  sed -i "s/$search/$replace/g" "$file"
}

download() {
  local url=$1 file="$2"
  print_info "downloading $file"
  print_info "from URL: $url"
  wget $url -qO "$file"
}

check_file_integrity() {
  local checksum=$1 file=$2
  SHA256SUM_RESULT=$(printf "%s %s" "$checksum" "$file" | sha256sum -c)
  if [ "${SHA256SUM_RESULT}" = "${file}: OK" ]; then
    print_info "checking sha256sum of file: $file"
  else
    print_error "sha256sum check failed: $file"
    exit 0
  fi
  print_success "sha256sum check passed: $file"
}

setup_service() {
  local name="$1" command="$2"
  create_start_script "$name" "$command"
  create_unit_file "$name"
  mv -f "${name}.sh" "$unit_files_dir/${name}.sh"
  mv -f "${name}.service" "$unit_files_dir/${name}.service"
  enable_service "$name"
}

enable_service() {
  local name=$1
  chown -R "$SUDO_USER":"$group_name" "$conda_install_dir"
  systemctl daemon-reload
  systemctl enable "$name"
}

create_start_script() {
  local name="$1" command="$2"
  cat >"${name}.sh" <<EOL
#!/bin/bash

source $conda_install_dir/etc/profile.d/conda.sh
conda activate $env_name
$conda_run $command

EOL
}

create_unit_file() {
  cat >"${name}.service" <<EOL
[Unit]
Description=${name} service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=${unit_files_dir}/${name}.sh

[Install]
WantedBy=multi-user.target

EOL
}

initialize_fts_yaml() {
  cat <<EOF >"/tmp/FTSConfig.yaml"
System:
  #FTS_DATABASE_TYPE: SQLite
  FTS_CONNECTION_MESSAGE: Welcome to FreeTAKServer {MainConfig.version}. The Parrot is not dead. It's just resting
  #FTS_OPTIMIZE_API: True
  #FTS_MAINLOOP_DELAY: 1
Addresses:
  #FTS_COT_PORT: 8087
  #FTS_SSLCOT_PORT: 8089
  FTS_DP_ADDRESS: $fts_ip
  FTS_USER_ADDRESS: $fts_ip
  #FTS_API_PORT: 19023
  #FTS_FED_PORT: 9000
  #FTS_API_ADDRESS: $fts_ip
FileSystem:
  FTS_DB_PATH: /opt/FreeTAKServer.db
  #FTS_COT_TO_DB: True
  FTS_MAINPATH: $sitepackages/$fts_package
  #FTS_CERTS_PATH: $sitepackages/$fts_package/certs
  #FTS_EXCHECK_PATH: $sitepackages/$fts_package/ExCheck
  #FTS_EXCHECK_TEMPLATE_PATH: $sitepackages/$fts_package/ExCheck/template
  #FTS_EXCHECK_CHECKLIST_PATH: $sitepackages/$fts_package/ExCheck/checklist
  #FTS_DATAPACKAGE_PATH: $sitepackages/$fts_package/FreeTAKServerDataPackageFolder
  #FTS_LOGFILE_PATH: $sitepackages/$fts_package/Logs
Certs:
  #FTS_SERVER_KEYDIR: $sitepackages/$fts_package/certs/server.key
  #FTS_SERVER_PEMDIR: $sitepackages/$fts_package/certs/server.pem
  #FTS_TESTCLIENT_PEMDIR: $sitepackages/$fts_package/certs/Client.pem
  #FTS_TESTCLIENT_KEYDIR: $sitepackages/$fts_package/certs/Client.key
  #FTS_UNENCRYPTED_KEYDIR: $sitepackages/$fts_package/certs/server.key.unencrypted
  #FTS_SERVER_P12DIR: $sitepackages/$fts_package/certs/server.p12
  #FTS_CADIR: $sitepackages/$fts_package/certs/ca.pem
  #FTS_CAKEYDIR: $sitepackages/$fts_package/certs/ca.key
  #FTS_FEDERATION_CERTDIR: $sitepackages/$fts_package/certs/server.pem
  #FTS_FEDERATION_KEYDIR: $sitepackages/$fts_package/certs/server.key
  #FTS_CRLDIR: $sitepackages/$fts_package/certs/FTS_CRL.json
  #FTS_FEDERATION_KEYPASS: demopassfed
  #FTS_CLIENT_CERT_PASSWORD: demopasscert
  #FTS_WEBSOCKET_KEY: YourWebsocketKey

EOF
}

initialize_fts_ui_config() {
  cat <<EOF >"/tmp/config.py"
# -*- encoding: utf-8 -*-
"""
License: MIT
Copyright (c) 2019 - present AppSeed.us
"""
import os
from os import environ


class Config(object):

    basedir = os.path.abspath(os.path.dirname(__file__))

    SECRET_KEY = 'key'

    # This will connect to the FTS db
    SQLALCHEMY_DATABASE_URI = 'sqlite:///' + '/opt/FTSServer-UI.db'

    # certificates path
    certpath = "$sitepackages/$fts_package/certs/"

    # crt file path
    crtfilepath = f"{certpath}pubserver.pem"

    # key file path
    keyfilepath = f"{certpath}pubserver.key.unencrypted"

    # this IP will be used to connect with the FTS API
    IP = '$fts_ip'

    # Port the  UI uses to communicate with the API
    PORT = '19023'

    # the public IP your server is exposing
    APPIP = '$fts_ip'

    # webmap IP
    WEBMAPIP = '$webmap_ip'

    # webmap port
    WEBMAPPORT = 8000

    # this port will be used to listen
    APPPort = 5000

    # the webSocket  key used by the UI to communicate with FTS.
    WEBSOCKETKEY = 'YourWebsocketKey'

    # the API key used by the UI to comunicate with FTS. generate a new system user and then set it
    APIKEY = 'Bearer token'

    # For 'in memory' database, please use:
    # SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'

    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # THEME SUPPORT
    #  if set then url_for('static', filename='', theme='')
    #  will add the theme name to the static URL:
    #    /static/<DEFAULT_THEME>/filename
    # DEFAULT_THEME = "themes/dark"
    DEFAULT_THEME = None


class ProductionConfig(Config):
    DEBUG = False

    # Security
    SESSION_COOKIE_HTTPONLY = True
    REMEMBER_COOKIE_HTTPONLY = True
    REMEMBER_COOKIE_DURATION = 3600

    # PostgreSQL database
    SQLALCHEMY_DATABASE_URI = 'postgresql://{}:{}@{}:{}/{}'.format(
        environ.get('APPSEED_DATABASE_USER', 'appseed'),
        environ.get('APPSEED_DATABASE_PASSWORD', 'appseed'),
        environ.get('APPSEED_DATABASE_HOST', 'db'),
        environ.get('APPSEED_DATABASE_PORT', 5432),
        environ.get('APPSEED_DATABASE_NAME', 'appseed')
    )


class DebugConfig(Config):
    DEBUG = True


config_dict = {
    'Production': ProductionConfig,
    'Debug': DebugConfig
}

EOF
}

clone_fts_installer_repo() {
  if [[ ! -d ~/$fts_install_repo ]]; then
    $conda_run git clone "$base_repo/$fts_install_repo" "$user_home/$fts_install_repo"
  else
    $conda_run git -C "$user_home/$fts_install_repo" pull
  fi
}

run_playbook() {
  conda install --name "$env_name" --channel conda-forge ansible
  EXTRA_VARS=-e "CONDA_PREFIX=$CONDA_PREFIX" -e "env_name=$env_name"
  if [[ -n "${CORE}" ]]; then
    $conda_run ansible-playbook -u "$SUDO_USER", "$IP_ARG", --connection=local "$EXTRA_VARS" install_mainserver.yml -vvv
  else
    $conda_run ansible-playbook -u "$SUDO_USER", "$IP_ARG", --connection=local "$EXTRA_VARS" install_all.yml -vvv
  fi
}

manual_fts_build() {
  # TODO: currently unused, kept for resiliency
  if [[ ! -d "$CONDA_PREFIX/$fts_repo" ]]; then
    $user_exec $conda_run git clone "$base_repo/$fts_repo" "$CONDA_PREFIX/$fts_repo"
  else
    cd "$CONDA_PREFIX/$fts_repo" && $conda_run git pull
  fi
  $user_exec $conda_run python "$CONDA_PREFIX/$fts_repo/setup.py" install
  chown -R "$SUDO_USER":"$group_name" "$CONDA_PREFIX/$fts_repo/$fts_package"
  mv -f "$CONDA_PREFIX/$fts_repo/$fts_package" "$sitepackages"
}

identify_system() {
  # detect Debian-family OS (Ubuntu)
  if [ -f /etc/debian_version ]; then
    id="$(grep "^ID=" /etc/os-release | awk -F= '{ print $2 }')"
    SYSTEM_DIST="$id"
    if [ "$SYSTEM_DIST" = "debian" ]; then
      SYSTEM_PSEUDO_NAME=$(grep "^VERSION=" /etc/os-release | awk -F= '{ print $2 }' | grep -oEi '[a-z]+')
      SYSTEM_VERSION=$(cat /etc/debian_version)
    elif [ "$SYSTEM_DIST" = "ubuntu" ]; then
      SYSTEM_PSEUDO_NAME=$(grep '^DISTRIB_CODENAME' /etc/lsb-release | awk -F= '{ print $2 }')
      SYSTEM_VERSION=$(grep '^DISTRIB_RELEASE' /etc/lsb-release | awk -F= '{ print $2 }')
    fi
  fi

  # Detect if inside Docker
  if grep -iq docker /proc/1/cgroup 2>/dev/null || head -n 1 /proc/1/sched 2>/dev/null | grep -Eq '^(bash|sh) ' || [ -f /.dockerenv ]; then
    SYSTEM_CONTAINER="true"
  fi

  # lowercase vars
  SYSTEM_NAME=$(echo "$SYSTEM_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_DIST=$(echo "$SYSTEM_DIST" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_DIST_BASED_ON=$(echo "$SYSTEM_DIST_BASED_ON" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_PSEUDO_NAME=$(echo "$SYSTEM_PSEUDO_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_VERSION=$(echo "$SYSTEM_VERSION" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_ARCH=$(echo "$SYSTEM_ARCH" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_ARCH_NAME=$(echo "$SYSTEM_ARCH_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_KERNEL=$(echo "$SYSTEM_KERNEL" | tr "[:upper:]" "[:lower:]" | tr " " "_")

  # report detected system information
  print_info "SYSTEM_NAME=$SYSTEM_NAME"
  print_info "SYSTEM_DIST=$SYSTEM_DIST"
  print_info "SYSTEM_DIST_BASED_ON=$SYSTEM_DIST_BASED_ON"
  print_info "SYSTEM_PSEUDO_NAME=$SYSTEM_PSEUDO_NAME"
  print_info "SYSTEM_VERSION=$SYSTEM_VERSION"
  print_info "SYSTEM_ARCH=$SYSTEM_ARCH"
  print_info "SYSTEM_ARCH_NAME=$SYSTEM_ARCH_NAME"
  print_info "SYSTEM_KERNEL=$SYSTEM_KERNEL"

  local is_supported=false

  print_info "list of supported operating systems: "

  # check for supported os
  for candidate_os in "${supported_os[@]}"; do
    local supported_os_version="$SYSTEM_DIST $SYSTEM_VERSION"
    print_info "    $supported_os_version"
    if [[ "$SYSTEM_DIST $SYSTEM_VERSION" = "$candidate_os" ]]; then
      is_supported=true
    fi
  done

  # if not a supported operating system, warn the user
  if [ $is_supported = false ]; then
    print_warn "DID NOT DETECT A SUPPORTED OPERATING SYSTEM\n"
    read -r -e -p "Do you want to continue? [y/n]: " PROCEED
    if [[ "${PROCEED:-n}" != "y" ]]; then
      print_warn "Answer was not y (yes). Exiting."
      exit 1
    fi
  fi

  print_success "found supported operating system: $candidate_os"
}

setup_virtual_environment() {
  local conda_filename="Miniconda3-py38_4.11.0-Linux-x86_64.sh"
  local conda_installer=$(mktemp --suffix ".$conda_filename") || false
  local conda_url="https://repo.anaconda.com/miniconda/$conda_filename"
  local conda_sha256="4bb91089ecc5cc2538dece680bfe2e8192de1901e5e420f63d4e78eb26b0ac1a"

  # download conda
  conda_install_dir="$user_home/conda"
  download $conda_url "$conda_installer"
  check_file_integrity "$conda_sha256" "$conda_installer"

  print_info "installing conda virtual environment"
  mkdir -p "$conda_install_dir"
  bash "$conda_installer" -u -b -p "$conda_install_dir" >/dev/null 2>&1

  print_info "setting permissions for conda virtual environment"
  groupadd -f "$group_name"
  usermod -a -G "$group_name" "$SUDO_USER"
  chgrp "$group_name" "/usr/local/bin"
  ln -sf "$conda_install_dir/bin/conda" "/usr/local/bin/conda"

  print_info "configuring conda virtual environment"
  source "$conda_install_dir/etc/profile.d/conda.sh"
  conda update --yes --name base conda >/dev/null 2>&1
  conda config --set auto_activate_base true --set always_yes yes --set changeps1 yes

  print_info "creating virtual environment: $env_name"
  conda create --name "$env_name" python="$python_version" >/dev/null 2>&1

  print_info "activating virtual environment"
  $user_exec conda init bash >/dev/null 2>&1
  eval "$(conda shell.bash hook)"
  conda activate "$env_name"

  # ensure permissions after activate
  chown -R "$SUDO_USER":"$group_name" "$conda_install_dir"

  # set conda variables to facilitate later installation steps
  conda_run="conda run -n $env_name"
  python_exec=$($conda_run which python${python_version})
  sitepackages="$CONDA_PREFIX/lib/python${python_version}/site-packages"

  print_success "done installing virtual environment"
}

fts_shell_install() {
  print_info "installing Free TAK Server (FTS)"
  $user_exec $conda_run python -m pip install --no-input "$fts_package" >/dev/null 2>&1

  print_info "configuring FTS"

  # setup MainConfig.py file
  local search="    first_start = True"
  local replace="    first_start = False"
  replace "$sitepackages/$fts_package/controllers/configuration/MainConfig.py" "$search" "$replace"

  # setup FTSConfig.yaml file
  initialize_fts_yaml
  chgrp "$group_name" "/tmp/FTSConfig.yaml"
  mv -f "/tmp/FTSConfig.yaml" "/opt/FTSConfig.yaml"

  print_info "setting up FTS to automatically start"
  local fts_command="$python_exec -m FreeTAKServer.controllers.services.FTS"
  setup_service "$fts_service" "$fts_command"
}

fts_ui_shell_install() {
  print_info "installing FTS User Interface"
  $user_exec $conda_run python -m pip install --no-input "$fts_ui_package"

  print_info "configuring FTS User Interface"
  initialize_fts_ui_config
  chgrp "$group_name" "/tmp/config.py"
  mv -f "/tmp/config.py" "$sitepackages/$fts_ui_package/config.py"

  print_info "setting up FTS User Interface to automatically start"
  local fts_ui_command="$python_exec  $sitepackages/$fts_ui_package/run.py"
  setup_service "$fts_ui_service" "$fts_ui_command"
}

webmap_shell_install() {
  print_info "downloading webmap"
  wget $webmap_url -qO "/tmp/$webmap_filename"
  check_file_integrity "$webmap_sha256" "/tmp/$webmap_filename"

  print_info "installing webmap"

  # unzip webmap
  chmod 777 "/tmp/$webmap_filename"
  $user_exec conda install -y --name "$env_name" unzip >/dev/null 2>&1
  $conda_run unzip -o "/tmp/$webmap_filename" -d /tmp >/dev/null 2>&1

  # remove version string
  mv -f "/tmp/$webmap_executable" "/tmp/$webmap_name"

  # move to destination directory
  chgrp "$group_name" "/tmp/$webmap_name"
  mv -f "/tmp/$webmap_name" "$webmap_install_dir/$webmap_name"

  print_info "configuring webmap"

  # configure ip in webMAP_config.json
  local search="\"FTH_FTS_URL\": \"0.0.0.0\","
  local replace="\"FTH_FTS_URL\": \"$my_ipv4\","
  replace "/tmp/$webmap_config" "$search" "$replace"
  chgrp "$group_name" "/tmp/$webmap_config"
  mv -f "/tmp/$webmap_config" "/opt/$webmap_config"

  print_info "setting up webmap to automatically start"
  local webmap_command="/usr/local/bin/$webmap_name /opt/$webmap_config"
  setup_service "$webmap_service" "$webmap_command"
}

install_components() {
  if [[ -n "$use_ansible" ]]; then
    clone_fts_installer_repo
    run_playbook
  else
    fts_shell_install
    fts_ui_shell_install
    webmap_shell_install
  fi
}

start_services() {
  systemctl start "$fts_service"
  systemctl start "$fts_ui_service"
  systemctl start "$webmap_service"
}

main "$@"
