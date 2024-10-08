#!/usr/bin/env bash
#: Free TAK Server Installation Script

# enforce failfast
set -o errexit
set -o nounset
set -o pipefail

# trap or catch signals and direct execution to cleanup
trap cleanup SIGINT SIGTERM ERR EXIT

REPO="https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git"

###############################################################################
# Print out helpful message.
# Outputs:
#   Writes usage message to stdout
###############################################################################
function usage() {
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") [<optional-arguments>]

Install Free TAK Server and components.

Available options:

-h,   --help               Print help
-v,   --verbose            Print script debug info
-c,   --check              Check for compatibility issues while installing
      --non-interactive    Assume defaults (non-interactive)
      --core               Install FreeTAKServer, UI, and Web Map
      --nodered            Install Node-RED Server
      --video              Install Video Server
      --mumble             Install Murmur VOIP Server and Mumble Client
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

  # The default 'apt verbosity' is verbose. Set it to quiet, since that's what our script assumes
  # unset this later if we want verbosity
  APT_VERBOSITY="-qq"

  while true; do
    case "${1-}" in

    --help | -h)
      usage
      exit 0
      shift
      ;;

    --verbose | -v)
      # set -x

      NO_COLOR=1
      GIT_TRACE=true
      GIT_CURL_VERBOSE=true
      GIT_SSH_COMMAND="ssh -vvv"
      unset APT_VERBOSITY # verbose is the default
      ANSIBLE_VERBOSITY="-vv"

      shift
      ;;

    --check | -c)
      CHECK=1
      shift
      ;;

    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;

    --core)
      CORE="y"
      shift
      ;;

    --nodered)
      NODERED="y"
      shift
      ;;

    --video)
      VIDEO="y"
      shift
      ;;

    --mumble)
      MUMBLE="y"
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

  if [[ -n "${CHECK-}" ]]; then
    check_os
    # check_architecture
  else
    WEBMAP_FORCE_INSTALL="-e webmap_force_install=true"
  fi

  if [[ -n "${TEST-}" ]]; then
      REPO="https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git"
  fi

}

###############################################################################
# Check if script was ran as root. This script requires root execution.
###############################################################################
function check_root() {

  echo -e -n "${BLUE}Checking if this script is running as root...${NOFORMAT}"

  # check Effective User ID (EUID) for root user, which has an EUID of 0.
  if [[ "$EUID" -ne 0 ]]; then

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
  if [[ -f /etc/os-release ]]; then

    . /etc/os-release

    OS=${NAME}
    VER=${VERSION_ID}

  # linuxbase.org
  elif type lsb_release >/dev/null 2>&1; then

    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)

  # for some Debian-based distros
  elif [[ -f /etc/lsb-release ]]; then

    . /etc/lsb-release

    OS=${DISTRIB_ID}
    VER=${DISTRIB_RELEASE}

  # older Debian-based distros
  elif [[ -f /etc/debian_version ]]; then

    OS=Debian
    VER=$(cat /etc/debian_version)

  # fallback
  else

    OS=$(uname -s)
    VER=$(uname -r)

  fi

  # check for supported OS and version and warn if not supported
  if [[ "${OS}" != "Ubuntu" ]] || [[ "${VER}" != "20.04" ]]; then

    echo -e "${YELLOW}WARNING${NOFORMAT}"
    echo "FreeTAKServer has only been tested on ${GREEN}Ubuntu 20.04${NOFORMAT}."
    echo -e "This machine is currently running: ${YELLOW}${OS} ${VER}${NOFORMAT}"
    echo "Errors may arise during installation or execution."

    read -r -e -p "Do you want to continue? [y/n]: " PROCEED

    # Default answer is "n" for NO.
    DEFAULT="n"

    # Set user-inputted value and apply default if user input is null.
    PROCEED="${PROCEED:-${DEFAULT}}"

    # Check user input to proceed or not.
    if [[ "${PROCEED}" != "y" ]]; then
      die "Answer was not y. Not proceeding."
    else
      echo -e "${GREEN}Proceeding...${NOFORMAT}"
    fi

    # Check user input to proceed or not.
    if [[ "${PROCEED}" != "y" ]]; then
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

  # check for non-Intel-based architecture here
  arch=$(uname --hardware-platform) # uname is non-portable, but we only target Ubuntu 20.04
  if ! grep --ignore-case x86 <<<"${arch}" >/dev/null; then

    echo -e "${YELLOW}WARNING${NOFORMAT}"
    echo "Possible non-Intel architecture detected."
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
    echo "Intel architecture detected."

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

  sudo apt-get -y ${APT_VERBOSITY--qq} update

  echo -e "${BLUE}Installing Ansible...${NOFORMAT}"
  sudo apt-get -y ${APT_VERBOSITY--qq} install ansible

  echo -e "${BLUE}Installing Git...${NOFORMAT}"
  sudo apt-get -y ${APT_VERBOSITY--qq} install git


}

###############################################################################
# Handle git repository
###############################################################################
function handle_git_repository() {

  echo -e -n "${BLUE}Checking for FreeTAKHub-Installation in home directory..."

  cd ~

  # check for FreeTAKHub-Installation repository
  if [[ ! -d ~/FreeTAKHub-Installation ]]; then

    echo -e "NOT FOUND"
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
# Run Default Ansible Playbooks
###############################################################################
function run_defaults() {
  ansible-playbook -u root -i localhost, --connection=local -e webmap_force_install=true install_mainserver.yml ${ANSIBLE_VERBOSITY-}
  ansible-playbook -u root -i localhost, --connection=local install_murmur.yml ${ANSIBLE_VERBOSITY-}
  ansible-playbook -u root -i localhost, --connection=local install_videoserver.yml ${ANSIBLE_VERBOSITY-}
  ansible-playbook -u root -i localhost, --connection=local "${IP_VARS}" install_noderedserver.yml ${ANSIBLE_VERBOSITY-}
}

###############################################################################
# Prompt The User To Select
###############################################################################
function prompt_user_selection() {
  [[ -z "${CORE-}" ]] && read -r -e -p "Install FreeTAKServer? [y/n] (default: y): " MAINSERVER_REPONSE
  [[ -z "${MUMBLE-}" ]] && read -r -e -p "Install Murmur VOIP Server and Mumble Client? [y/n] (default: y): " MURMUR_REPONSE
  [[ -z "${VIDEO-}" ]] && read -r -e -p "Install Video Server? [y/n] (default: y): " VIDEOSERVER_REPONSE
  [[ -z "${NODERED-}" ]] && read -r -e -p "Install Node-RED Server? [y/n] (default: y): " NODEREDSERVER_REPONSE

  [[ -n "${MAINSERVER_REPONSE-}" ]] && CORE=${MAINSERVER_REPONSE:-y}
  [[ -n "${MURMUR_REPONSE-}" ]] && MUMBLE=${MURMUR_REPONSE:-y}
  [[ -n "${VIDEOSERVER_REPONSE-}" ]] && VIDEO=${VIDEOSERVER_REPONSE:-y}
  [[ -n "${NODEREDSERVER_REPONSE-}" ]] && NODERED=${NODEREDSERVER_REPONSE:-y}
}

###############################################################################
# Select FreeTAKHub Components and Install
###############################################################################
function run_playbooks() {

  IP_VARS="-e videoserver_ipv4=localhost -e fts_ipv4=localhost"

  if [[ -n "${NON_INTERACTIVE}" ]]; then
      run_defaults
  else
    prompt_user_selection
  fi

  echo -e "${BLUE}Running Ansible Playbooks...${NOFORMAT}"

  [ "${CORE-}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local "${WEBMAP_FORCE_INSTALL-}" install_mainserver.yml ${ANSIBLE_VERBOSITY-}
  [ "${MUMBLE-}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local install_murmur.yml ${ANSIBLE_VERBOSITY-}
  [ "${VIDEO-}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local install_videoserver.yml ${ANSIBLE_VERBOSITY-}
  [ "${NODERED-}" == "y" ] && ansible-playbook -u root -i localhost, --connection=local "${IP_VARS}" install_noderedserver.yml ${ANSIBLE_VERBOSITY-}

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
