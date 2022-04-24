#!/usr/bin/env bash
#: Free TAK Server Installation Script

# enforce failfast
set -o errexit
set -o pipefail

# trap or catch signals and direct execution to cleanup
trap cleanup SIGINT SIGTERM ERR EXIT
trap ctrl_c INT

REPO="https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git"

CONDA_FILENAME="Miniconda3-py38_4.11.0-Linux-x86_64.sh"
CONDA_INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-py38_4.11.0-Linux-x86_64.sh"
CONDA_SHA256SUM="4bb91089ecc5cc2538dece680bfe2e8192de1901e5e420f63d4e78eb26b0ac1a"
CONDA_INSTALLER=$(mktemp --suffix ".$CONDA_FILENAME")
CONDA_INSTALL_DIR="${HOME}/conda"

VENV_NAME="fts"
PYTHON_VERSION=3.8

###############################################################################
# SUPPORTED OS VARIABLES
###############################################################################
declare SUPPORTED_OS=(
  "ubuntu 20.04"
)

###############################################################################
# SYSTEM VARIABLES
###############################################################################
SYSTEM_NAME=$(uname)
SYSTEM_DIST="Unknown"
SYSTEM_DIST_BASED_ON="Unknown"
SYSTEM_PSEUDO_NAME="Unknown"
SYSTEM_VERSION="Unknown"
SYSTEM_ARCH=$(uname -m)
SYSTEM_ARCH_NAME="Unknown" # {i386, amd64, arm64}
SYSTEM_KERNEL=$(uname -r)
SYSTEM_CONTAINER="false"
CLOUD_PROVIVDER="false"

newline() { printf "\n"; }

go_up() { echo -en "\033[${1}A"; }

_clear() { echo -en "\033[K"; }

clear() {
  go_up 1
  _clear
}

progress_clear() {
  clear
  progress "${1}" "${2}"
}

path_add() {
  if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
    PATH="${PATH:+"$PATH:"}$1"
  fi
}

###############################################################################
# Print out helpful message.
# Outputs:
#   Writes usage message to stdout
###############################################################################
function usage() {
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]:-}") [<optional-arguments>]

Install Free TAK Server and components.

Available options:

-h, --help       Print help
-v, --verbose    Print script debug info
-c, --check      Check for compatibility issues while installing
    --core       Install FreeTAKServer, UI, and Web Map
USAGE_TEXT
  exit
}

###############################################################################
# Cleanup here
###############################################################################
function cleanup() {
  trap - SIGINT SIGTERM ERR EXIT

  progress BUSY "cleaning up"
  _cleanup
  progress_clear DONE "cleaning up"

  die
}

function _cleanup() {
  rm -f "${CONDA_INSTALLER}"
}

###############################################################################
# Interrupt Cleanup
###############################################################################
function ctrl_c() {
  trap - INT

  _cleanup

  printf "\b\b"

  # clear line
  progress WARN "interrupted installation"

  die "" 1
}

###############################################################################
# Echo a message
###############################################################################
function msg() {
  echo -e "${1:-}" >&2
}

###############################################################################
# Exit gracefully
###############################################################################
function die() {

  # default exit status 0
  local -i code=${2:-0}
  local msg=${1:-"exiting"}

  if [ $code -ne 0 ]; then
    progress FAIL "$msg"
  fi

  exit 0
}

###############################################################################
# STATUS VARIABLES
###############################################################################
declare -i EXIT_SUCCESS=0
declare -i EXIT_FAILURE=1
FOREGROUND="\033[39m"
NOFORMAT="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW='\033[1;33m'
BLUE='\033[1;34m'

declare -A STATUS_COLOR=(
  [DONE]=$GREEN
  [FAIL]=$RED
  [INFO]=$FOREGROUND
  [WARN]=$YELLOW
  [BUSY]=$YELLOW
  [EXIT]=$FOREGROUND
)

declare -A STATUS_TEXT=(
  [DONE]=" DONE "
  [FAIL]=" FAIL "
  [INFO]=" INFO "
  [WARN]=" WARN "
  [BUSY]=" BUSY "
  [EXIT]=" EXIT "
)

function progress() {

  echo -e "[  ${STATUS_COLOR[$1]}${STATUS_TEXT[$1]}${NOFORMAT}  ] ${2}"

}

###############################################################################
# Parse parameters
###############################################################################

# verbose by default
# v_apt="-qq"
# v_bash=/dev/null
function parse_params() {
  progress BUSY "parsing input parameters"

  while true; do
    case "${1-}" in

    --help | -h)
      usage
      exit 0
      shift
      ;;

    --verbose | -v)
      set -x

      NO_COLOR=1
      # GIT_TRACE=true
      # GIT_CURL_VERBOSE=true
      # GIT_SSH_COMMAND="ssh -vvv"
      # v_ansible="-vv"
      # unset v_apt
      # unset v_bash

      shift
      ;;

    --check | -c)
      CHECK=1
      shift
      ;;

    --core)
      CORE=1
      shift
      ;;

    --dev-test)
      TEST=1
      shift
      ;;

    --no-color)
      NO_COLOR=1
      shift
      ;;

    -?*)
      die "FAIL: unknown option $1"
      ;;

    *)
      break
      ;;

    esac
  done

  progress_clear DONE "parsing input parameters"
}

###############################################################################
# Check if script was ran as root. This script requires root execution.
###############################################################################
function check_root() {
  progress BUSY "checking if user is root"

  # check Effective User ID (EUID) for root user, which has an EUID of 0.
  if [[ "$EUID" -ne 0 ]]; then
    progress_clear FAIL "This script requires running as root. Use sudo before the command."
    exit ${EXIT_FAILURE}
  fi
  progress_clear DONE "checking if user is root"
}

function identify_cloud() {

  if dmidecode --string "bios-vendor" | grep -iq "digitalocean"; then # DigitalOcean
    CLOUD_PROVIDER="digitalocean"
  elif dmidecode -s bios-version | grep -iq "amazon"; then # Amazon Web Services
    CLOUD_PROVIDER="amazon"
  elif dmidecode -s system-manufacturer | grep -iq "microsoft corporation"; then # Microsoft Azure
    CLOUD_PROVIDER="azure"
  elif dmidecode -s bios-version | grep -iq "google"; then # Google Cloud Platform
    CLOUD_PROVIDER="google"
  elif dmidecode -s bios-version | grep -iq "ovm"; then # Oracle Cloud Infrastructure
    CLOUD_PROVIDER="oracle"
  fi

}

function identify_docker() {

  # Detect if inside Docker
  if grep -iq docker /proc/1/cgroup 2>/dev/null || head -n 1 /proc/1/sched 2>/dev/null | grep -Eq '^(bash|sh) ' || [ -f /.dockerenv ]; then
    SYSTEM_CONTAINER="true"
  fi

}

###############################################################################
# Check for supported system and warn user if not supported.
###############################################################################
function identify_system() {

  progress BUSY "identifying system attributes"

  if uname -s | grep -iq "darwin"; then # Detect macOS
    SYSTEM_NAME="unix"
    SYSTEM_DIST="macos"
    SYSTEM_DIST_BASED_ON="bsd"
    sw_vers -productVersion | grep -q 10.10 && SYSTEM_PSEUDO_NAME="Yosemite"
    sw_vers -productVersion | grep -q 10.11 && SYSTEM_PSEUDO_NAME="El Capitan"
    sw_vers -productVersion | grep -q 10.12 && SYSTEM_PSEUDO_NAME="Sierra"
    sw_vers -productVersion | grep -q 10.13 && SYSTEM_PSEUDO_NAME="High Sierra"
    sw_vers -productVersion | grep -q 10.14 && SYSTEM_PSEUDO_NAME="Mojave"
    sw_vers -productVersion | grep -q 10.15 && SYSTEM_PSEUDO_NAME="Catalina"
    sw_vers -productVersion | grep -q 11. && SYSTEM_PSEUDO_NAME="Big Sur"
    sw_vers -productVersion | grep -q 12. && SYSTEM_PSEUDO_NAME="Monterey"
    SYSTEM_VERSION=$(sw_vers -productVersion)
    SYSTEM_ARCH_NAME="i386"
    uname -m | grep -q "x86_64" && SYSTEM_ARCH_NAME="amd64"
    uname -m | grep -q "arm" && SYSTEM_ARCH_NAME="arm64"

  elif [ -f /etc/debian_version ]; then # Detect Debian family
    id="$(grep "^ID=" /etc/os-release | awk -F= '{ print $2 }')"
    SYSTEM_DIST="$id"
    if [ "$SYSTEM_DIST" = "debian" ]; then
      SYSTEM_PSEUDO_NAME=$(grep "^VERSION=" /etc/os-release | awk -F= '{ print $2 }' | grep -oEi '[a-z]+')
      SYSTEM_VERSION=$(cat /etc/debian_version)
    elif [ "$SYSTEM_DIST" = "ubuntu" ]; then
      SYSTEM_PSEUDO_NAME=$(grep '^DISTRIB_CODENAME' /etc/lsb-release | awk -F= '{ print $2 }')
      SYSTEM_VERSION=$(grep '^DISTRIB_RELEASE' /etc/lsb-release | awk -F= '{ print $2 }')
    elif [ "$SYSTEM_DIST" = "kali" ]; then
      SYSTEM_PSEUDO_NAME=$(grep "^PRETTY_NAME=" /etc/os-release | awk -F= '{ print $2 }' | sed s/\"//g | awk '{print $NF}')
      SYSTEM_VERSION=$(grep "^VERSION=" /etc/os-release | awk -F= '{ print $2 }' | sed s/\"//g)
    fi
    SYSTEM_DIST_BASED_ON="debian"
    SYSTEM_ARCH_NAME="i386"
    uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
    { uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"

  elif [ -f /etc/redhat-release ]; then # Detect RedHat family
    SYSTEM_DIST=$(sed s/\ release.*// /etc/redhat-release | tr "[:upper:]" "[:lower:]")
    echo "$SYSTEM_DIST" | grep -q "red" && SYSTEM_DIST="redhat"
    echo "$SYSTEM_DIST" | grep -q "centos" && SYSTEM_DIST="centos"
    SYSTEM_DIST_BASED_ON="redhat"
    SYSTEM_PSEUDO_NAME=$(sed s/.*\(// /etc/redhat-release | sed s/\)//)
    SYSTEM_VERSION=$(sed s/.*release\ // /etc/redhat-release | sed s/\ .*//)
    SYSTEM_ARCH_NAME="i386"
    uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
    { uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"

  elif which apk >/dev/null 2>&1; then # Detect Alpine
    SYSTEM_DIST="alpine"
    SYSTEM_DIST_BASED_ON="alpine"
    SYSTEM_PSEUDO_NAME=
    SYSTEM_VERSION=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' /etc/alpine-release)
    SYSTEM_ARCH_NAME="i386"
    uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
    { uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"

  elif which busybox >/dev/null 2>&1; then # Detect Busybox
    SYSTEM_DIST="busybox"
    SYSTEM_DIST_BASED_ON="busybox"
    SYSTEM_PSEUDO_NAME=
    SYSTEM_VERSION=$(busybox | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    SYSTEM_ARCH_NAME="i386"
    uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
    { uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"

  elif grep -iq "amazon linux" /etc/os-release 2>/dev/null; then # Detect Amazon Linux
    SYSTEM_DIST="amazon"
    SYSTEM_DIST_BASED_ON="redhat"
    SYSTEM_PSEUDO_NAME=
    SYSTEM_VERSION=$(grep "^VARIANT_ID=" /etc/os-release | awk -F= '{ print $2 }' | sed s/\"//g)
    [ -z "$SYSTEM_VERSION" ] && SYSTEM_VERSION=$(grep "^VERSION_ID=" /etc/os-release | awk -F= '{ print $2 }' | sed s/\"//g)
    SYSTEM_ARCH_NAME="i386"
    uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
    { uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"
  fi

  # make vars lowercase
  SYSTEM_NAME=$(echo "$SYSTEM_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_DIST=$(echo "$SYSTEM_DIST" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_DIST_BASED_ON=$(echo "$SYSTEM_DIST_BASED_ON" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_PSEUDO_NAME=$(echo "$SYSTEM_PSEUDO_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_VERSION=$(echo "$SYSTEM_VERSION" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_ARCH=$(echo "$SYSTEM_ARCH" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_ARCH_NAME=$(echo "$SYSTEM_ARCH_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  SYSTEM_KERNEL=$(echo "$SYSTEM_KERNEL" | tr "[:upper:]" "[:lower:]" | tr " " "_")
  # echo "SYSTEM_CONTAINER=$(echo "$SYSTEM_CONTAINER" | tr "[:upper:]" "[:lower:]" | tr " " "_")"

  # echo "SYSTEM_NAME=$SYSTEM_NAME"
  # echo "SYSTEM_DIST=$SYSTEM_DIST"
  # echo "SYSTEM_DIST_BASED_ON=$SYSTEM_DIST_BASED_ON"
  # echo "SYSTEM_PSEUDO_NAME=$SYSTEM_PSEUDO_NAME"
  # echo "SYSTEM_VERSION=$SYSTEM_VERSION"
  # echo "SYSTEM_ARCH=$SYSTEM_ARCH"
  # echo "SYSTEM_ARCH_NAME=$SYSTEM_ARCH_NAME"
  # echo "SYSTEM_KERNEL=$SYSTEM_KERNEL"
  # echo "CLOUD_PROVIVDER=$(echo "$CLOUD_PROVIVDER" | tr "[:upper:]" "[:lower:]" | tr " " "_")"

  # iterate through supported operating systems
  local is_supported=false

  for candidate_os in "${SUPPORTED_OS[@]}"; do
    if [[ "$SYSTEM_DIST $SYSTEM_VERSION" = "$candidate_os" ]]; then
      is_supported=true
    fi
  done

  if [ $is_supported = false ]; then
    echo -e "${YELLOW}WARNING${NOFORMAT}"
    echo -e "running"
    echo -e "This machine is currently running: ${YELLOW}${OS} ${VER}${NOFORMAT}"
    echo "Errors may arise during installation or execution."
  fi

  # # check for supported OS and version and warn if not supported
  # if [[ "${SYSTEM_NAME} ${SYSTEM_VERSION}" != "Ubuntu" ]] || [[ "${VER}" != "20.04" ]]; then

  #   read -r -e -p "Do you want to continue? [y/n]: " PROCEED

  #   # Default answer is "n" for NO.
  #   DEFAULT="n"

  #   # Set user-inputted value and apply default if user input is null.
  #   PROCEED="${PROCEED:-${DEFAULT}}"

  #   # Check user input to proceed or not.
  #   if [[ "${PROCEED}" != "y" ]]; then
  #     die "Answer was not y. Not proceeding."
  #   else
  #     echo -e "${GREEN}Proceeding...${NOFORMAT}"
  #   fi

  # else

  #   echo -e "${GREEN}Success!${NOFORMAT}"
  #   echo -e "This machine is currently running: ${GREEN}${OS} ${VER}${NOFORMAT}"

  # fi

  progress_clear DONE "identifying system attributes"
}

###############################################################################
# Check for supported architecture
###############################################################################
function check_architecture() {

  progress BUSY "checking for supported architecture"

  # check for non-Intel-based architecture here
  arch=$(uname --hardware-platform) # uname is non-portable, but we only target Ubuntu 20.04
  if ! grep --ignore-case x86 <<<"${arch}" >/dev/null; then

    echo "Possible non-Intel architecture detected, ${name}"
    echo "Non-intel architectures may cause problems. The web map might not install."

    read -r -e -p "Do you want to force web map installation? [y/n]: " USER_INPUT

    # Default answer is "n" for NO.
    DEFAULT="n"

    # Set user-inputted value and apply default if user input is null.
    FORCE_WEBMAP_INSTALL_INPUT="${USER_INPUT:-${DEFAULT}}"

    # Check user input to force install web map or not
    if [[ "${FORCE_WEBMAP_INSTALL_INPUT}" != "y" ]]; then
      echo -e "${YELLOW}WARNING${NOFORMAT}: installer may skip web map installation."
    else
      WEBMAP_FORCE_INSTALL="-e webmap_force_install=true"
      echo -e "${YELLOW}WARNING${NOFORMAT}: forcing web map installation!"
    fi

  else # good architecture to install webmap
    echo -e "${GREEN}Success!${NOFORMAT}"
    echo "Intel architecture detected, ${name}"

  fi

  progress_clear DONE "checking for supported architecture"
}

###############################################################################
# check sha256sum
###############################################################################
function check_file_integrity() {

  local checksum=$1
  local file=$2

  progress BUSY "checking sha256sum of ${file}"
  SHA256SUM_RESULT=$(printf "%s %s" "$checksum" "$file" | sha256sum -c)

  if [ "${SHA256SUM_RESULT}" = "${file}: OK" ]; then
    progress_clear DONE "checking miniconda sha256sum"
  else
    progress_clear FAIL "sha256sum check failed: ${file}"
    exit $EXIT_FAILURE
  fi

}

###############################################################################
# setup miniconda virtual environment
###############################################################################
function setup_virtual_environment() {

  progress BUSY "downloading miniconda"
  wget ${CONDA_INSTALLER_URL} -qO "${CONDA_INSTALLER}"
  progress_clear DONE "downloading miniconda"

  check_file_integrity "$CONDA_SHA256SUM" "$CONDA_INSTALLER"

  progress BUSY "setting up virtual environment"

  mkdir -p "$CONDA_INSTALL_DIR"
  bash "$CONDA_INSTALLER" -u -b -p "$CONDA_INSTALL_DIR"
  "$CONDA_INSTALL_DIR/bin/conda" update --yes --quiet --name base conda
  ln -sf "$CONDA_INSTALL_DIR/bin/conda" /bin/conda

  conda create --quiet --name "$VENV_NAME" python="$PYTHON_VERSION"
  conda init --quiet bash

  # activate virtual environment
  eval "$(conda shell.bash hook)"
  conda activate "$VENV_NAME"

  # configure conda
  conda config --set auto_activate_base true --set always_yes yes --set changeps1 yes

  progress_clear DONE "setting up virtual environment"

  progress BUSY "downloading virtual environment dependencies"
  conda install --quiet conda
  conda install --quiet git
  conda install --quiet -c conda-forge ansible
  conda install --quiet pip
  progress_clear DONE "downloading virtual environment dependencies"

  VIRTUAL_ENVIRONMENT=$CONDA_DEFAULT_ENV
  VIRTUAL_ENVIRONMENT_FOLDER=$CONDA_PREFIX

}

###############################################################################
# Handle git repository
###############################################################################
function handle_git_repository() {

  cd ~

  # check for FreeTAKHub-Installation repository
  if [[ ! -d ~/FreeTAKHub-Installation ]]; then

    printf "NOT FOUND"
    echo -e "Cloning the FreeTAKHub-Installation repository...${NOFORMAT}"
    git clone ${REPO}

    cd ~/FreeTAKHub-Installation

  else

    echo -e "FOUND"

    cd ~/FreeTAKHub-Installation

    echo -e "Pulling latest from the FreeTAKHub-Installation repository...${NOFORMAT}"
    git pull

  fi

}

###############################################################################
# Add passwordless Ansible execution
###############################################################################
function add_passwordless_ansible_execution() {

  echo -e "${BLUE}Adding passwordless Ansible execution for the current user...${NOFORMAT}"

  # line to add
  LINE="${USER} ALL=(ALL) NOPASSWD:/usr/bin/ansible-playbook"

  # file to create for passwordless
  FILE="/etc/sudoers.d/dont-prompt-${USER}-for-sudo-password"

  # only add if non-existent
  grep -qF -- "${LINE}" "${FILE}" || echo "${LINE}" >>"${FILE}"

}

###############################################################################
# Generate public and private keys
###############################################################################
function generate_key_pair() {

  echo -e "${BLUE}Creating a public and private keys if non-existent...${NOFORMAT}"

  # check for public and private keys
  if [[ ! -e ${HOME}/.ssh/id_rsa.pub ]]; then

    # generate keys
    ssh-keygen -t rsa -f "${HOME}/.ssh/id_rsa" -N ""

  fi

}

###############################################################################
# Run Ansible playbook to install
###############################################################################
function run_playbook() {

  echo $VIRTUAL_ENVIRONMENT

  if [[ -n "${CORE-}" ]]; then
    ansible-playbook -u root -i localhost, --connection=local install_mainserver.yml
  else
    ansible-playbook -u root -i localhost, --connection=local install_all.yml
  fi

}

###############################################################################
# MAIN BUSINESS LOGIC HERE
###############################################################################

printf "INSTALLING FREE TAK SERVER"
newline

parse_params "${@}"
check_root
identify_system
identify_cloud
identify_docker
setup_virtual_environment

handle_git_repository
add_passwordless_ansible_execution
generate_key_pair
run_playbook

progress DONE "SUCCESSFUL INSTALLATION"
