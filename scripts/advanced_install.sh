#!/usr/bin/env bash
#: Free TAK Server Installation Script

# enforce failfast
set -o errexit
set -o nounset
set -o pipefail

# trap or catch signals and direct execution to cleanup
trap cleanup SIGINT SIGTERM ERR EXIT

###############################################################################
# Print out helpful message.
# Outputs:
#   Writes usage message to stdout
###############################################################################
function usage() {
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v]

Install Free TAK Server and components.

Available options:

-h, --help              Print help
-v, --verbose           Print script debug info
    --non-interactive   Auto install with no warning prompts
USAGE_TEXT
  exit
}

###############################################################################
# Cleanup here
###############################################################################
function cleanup() {

  trap - SIGINT SIGTERM ERR EXIT

  # script cleanup here

}

###############################################################################
# Echo a message
###############################################################################
function msg() {

  echo >&2 -e "${1-}"

}

###############################################################################
# Exit gracefully
###############################################################################
function die() {

  local msg=$1
  msg "$msg"

  echo -e "Exiting. Installation NOT successful."

  # default exit status 1
  local code=${2-1}
  exit "$code"

}

###############################################################################
# Parse parameters
###############################################################################
function parse_params() {

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

      # empty string means command is not silent by default
      APT_VERBOSITY=""
      GIT_VERBOSITY="-v"
      ANSIBLE_VERBOSITY="-vv"

      shift
      ;;

    --non-interactive)
      SKIP=1
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
      die "ERROR: unknown option $1"
      ;;

    *)
      break
      ;;

    esac
  done

}

###############################################################################
# Add coloration to output for highlighting or emphasizing words
###############################################################################
function setup_colors() {

  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then

    NOFORMAT='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    # ORANGE='\033[0;33m' # unused
    BLUE='\033[0;34m'
    # PURPLE='\033[0;35m' # unused
    # CYAN='\033[0;36m' # unused
    YELLOW='\033[1;33m'

  else

    NOFORMAT=''
    RED=''
    GREEN=''
    # ORANGE='' # unused
    BLUE=''
    # PURPLE='' # unused
    # CYAN='' # unused
    YELLOW=''

  fi

}

###############################################################################
# Do checks or skip unnecessary ones if non-interactive
###############################################################################
function do_checks() {

  check_root

  if [[ ! "${SKIP}" ]]; then
    check_os
    # check_architecture
  else
    FORCE_WEBMAP_INSTALL="y"
  fi

}

###############################################################################
# Check if script was ran as root. This script requires root execution.
###############################################################################
function check_root() {

  echo -e -n "${BLUE}Checking if this script is running as root...${NOFORMAT}"

  # check Effective User ID (EUID) for root user, which has an EUID of 0.
  if [ "$EUID" -ne 0 ]; then

    echo -e "${RED}ERROR${NOFORMAT}"
    die "This script requires running as root. Use sudo before the command."

  else

    echo -e "${GREEN}Success!${NOFORMAT}"

  fi
}

###############################################################################
# Check for supported operating system and warn user if not supported.
###############################################################################
function check_os() {

  echo -e -n "${BLUE}Checking for supported OS...${NOFORMAT}"

  # freedesktop.org and systemd
  if [ -f /etc/os-release ]; then

    . /etc/os-release

    OS=${NAME}
    VER=${VERSION_ID}

  # linuxbase.org
  elif type lsb_release >/dev/null 2>&1; then

    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)

  # for some Debian-based distros
  elif [ -f /etc/lsb-release ]; then

    . /etc/lsb-release

    OS=${DISTRIB_ID}
    VER=${DISTRIB_RELEASE}

  # older Debian-based distros
  elif [ -f /etc/debian_version ]; then

    OS=Debian
    VER=$(cat /etc/debian_version)

  # fallback
  else

    OS=$(uname -s)
    VER=$(uname -r)

  fi

  # check for supported OS and version and warn if not supported
  if [ "${OS}" != "Ubuntu" ] || [ "${VER}" != "20.04" ]; then

    echo -e "${YELLOW}WARNING${NOFORMAT}"
    echo "FreeTAKServer has only been tested on ${GREEN}Ubuntu 20.04${NOFORMAT}."
    echo -e "This machine is currently running: ${YELLOW}${OS} ${VER}${NOFORMAT}"
    echo "Errors may arise during installation or execution."

    # Check for non-interactive mode
    if [[ "${SKIP}" ]]; then
      PROCEED="y"
    else
      read -r -e -p "Do you want to continue? [y/n]: " PROCEED

      # Default answer is "n" for NO.
      DEFAULT="n"

      # Set user-inputted value and apply default if user input is null.
      PROCEED="${PROCEED:-${DEFAULT}}"
    fi

    # Check user input to proceed or not.
    if [ "${PROCEED}" != "y" ]; then
      die "Answer was not y. Not proceeding."
    else
      echo -e "${GREEN}Proceeding...${NOFORMAT}"
    fi

  else

    echo -e "${GREEN}Success!${NOFORMAT}"
    echo -e "This machine is currently running: ${GREEN}${OS} ${VER}${NOFORMAT}"

  fi

}

###############################################################################
# Check for supported architecture
###############################################################################
function check_architecture() {

  echo -e -n "${BLUE}Checking for supported architecture...${NOFORMAT}"

  # extract architecture string
  arch=$(cat /proc/cpuinfo | grep 'model name' | head -1)
  name=$(sed 's/.*CPU\s\(.*\)\s\(@\).*/\1/' <<<"${arch}")

  # check for non-Intel-based architecture here
  if ! grep Intel <<<"${arch}" >/dev/null; then

    echo -e "${YELLOW}WARNING${NOFORMAT}"
    echo "Possible non-Intel architecture detected, ${name}"
    echo "Non-intel architectures may cause problems. The web map might not install."

    read -r -e -p "Do you want to force web map installation? [y/n]: " FORCE_WEBMAP_INSTALL_INPUT

    # Default answer is "n" for NO.
    DEFAULT="n"

    # Set user-inputted value and apply default if user input is null.
    FORCE_WEBMAP_INSTALL_INPUT="${FORCE_WEBMAP_INSTALL_INPUT:-${DEFAULT}}"

    # Check user input to force install web map or not
    if [ "${FORCE_WEBMAP_INSTALL}" == "y" ]; then

      FORCE_INSTALL="-e webmap_force_install=true"
      echo -e "${YELLOW}WARNING${NOFORMAT}: forcing web map installation!"

    else
      echo -e "${YELLOW}WARNING${NOFORMAT}: installer may skip web map installation."

    fi

  else # good architecture to install webmap

    echo -e "${GREEN}Success!${NOFORMAT}"
    echo "Intel architecture detected, ${name}"

  fi

}

###############################################################################
# Download dependencies
###############################################################################
function download_dependencies() {

  echo -e "${BLUE}Downloading dependencies...${NOFORMAT}"

  echo -e "${BLUE}Adding the Ansible Personal Package Archive (PPA)...${NOFORMAT}"
  sudo apt-add-repository -y ppa:ansible/ansible

  echo -e "${BLUE}Downloading package information from configured sources...${NOFORMAT}"
  sudo apt-get -y ${APT_VERBOSITY-"-qq"} update

  echo -e "${BLUE}Installing Ansible...${NOFORMAT}"
  sudo apt-get -y ${APT_VERBOSITY-"-qq"} install ansible

  echo -e "${BLUE}Installing Git...${NOFORMAT}"
  sudo apt-get -y ${APT_VERBOSITY-"-qq"} install git

}

###############################################################################
# Handle git repository
###############################################################################
function handle_git_repository() {

  echo -e -n "${BLUE}Checking for FreeTAKHub-Installation in home directory..."

  cd ~

  # check for FreeTAKHub-Installation repository
  if [ ! -d ~/FreeTAKHub-Installation ]; then

    echo -e "NOT FOUND"

    echo -e "Cloning the FreeTAKHub-Installation repository...${NOFORMAT}"

    if [[ "${TEST-}" ]]; then
      git clone ${GIT_VERBOSITY--q} ${DEV_TEST_REPO}
    else
      git clone ${GIT_VERBOSITY-"-q"} https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
    fi

    cd ~/FreeTAKHub-Installation

  else

    echo -e "FOUND"

    cd ~/FreeTAKHub-Installation

    echo -e "Pulling latest from the FreeTAKHub-Installation repository...${NOFORMAT}"
    git pull ${GIT_VERBOSITY-"-q"}

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
# Select FreeTAKHub Components and Install
###############################################################################
function run_playbooks() {

  # Check for non-interactive mode
  if [[ "${SKIP}" ]]; then
      ansible-playbook -u root -i localhost, --connection=local -e webmap_force_install=true install_mainserver.yml ${ANSIBLE_VERBOSITY-}
      ansible-playbook -u root -i localhost, --connection=local install_murmur.yml ${ANSIBLE_VERBOSITY-}
      ansible-playbook -u root -i localhost, --connection=local install_videoserver.yml ${ANSIBLE_VERBOSITY-}
      ansible-playbook -u root -i localhost, --connection=local -e videoserver_ipv4=localhost install_noderedserver.yml ${ANSIBLE_VERBOSITY-}
  else
      read -r -p "Install FreeTAKServer? [y/n] (default: y): " response </dev/tty
      INSTALL_MAINSERVER=${response:-y}
      read -r -p "Install Murmur (Mumble VOIP Server)? [y/n] (default: y): " response </dev/tty
      INSTALL_MURMUR=${response:-y}
      read -r -p "Install Video Server? [y/n] (default: y): " response </dev/tty
      INSTALL_VIDEOSERVER=${response:-y}
      read -r -p "Install Node-RED Server? [y/n] (default: y): " response </dev/tty
      INSTALL_NODEREDSERVER=${response:-y}

      echo -e "${BLUE}Running Ansible Playbooks...${NOFORMAT}"
      [ "${INSTALL_MAINSERVER}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local ${WEBMAP_FORCE_INSTALL-} install_mainserver.yml ${ANSIBLE_VERBOSITY-}
      [ "${INSTALL_MURMUR}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local install_murmur.yml ${ANSIBLE_VERBOSITY-}
      [ "${INSTALL_VIDEOSERVER}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local install_videoserver.yml ${ANSIBLE_VERBOSITY-}
      [ "${INSTALL_NODEREDSERVER}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local -e videoserver_ipv4=localhost install_noderedserver.yml ${ANSIBLE_VERBOSITY-}
  fi

}

###############################################################################
# MAIN BUSINESS LOGIC HERE
###############################################################################
parse_params "${@}"
setup_colors
do_checks
download_dependencies
handle_git_repository
add_passwordless_ansible_execution
generate_key_pair
run_playbooks

exit 0
