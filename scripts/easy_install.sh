#!/usr/bin/env bash
#: Free TAK Server Installation Script
#: Author: John
#: Maintainers:
#: - Sypher
#: - nailshard

# enforce failfast
set -o errexit
set -o nounset
set -o pipefail

# This disables Apt's "restart services" interactive dialog
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1
NEEDRESTART=

# trap or catch signals and direct execution to cleanup
trap cleanup SIGINT SIGTERM ERR EXIT

DEFAULT_REPO="https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git"
REPO=${REPO:-$DEFAULT_REPO}
DEFAULT_BRANCH="main"
BRANCH=${BRANCH:-$DEFAULT_BRANCH}
CBRANCH=${CBRANCH:-}

STABLE_OS_REQD="Ubuntu"
STABLE_OS_VER_REQD="22.04"
STABLE_CODENAME_REQD="jammy"
LEGACY_OS_REQD="Ubuntu"
LEGACY_OS_VER_REQD="20.04"
LEGACY_CODENAME_REQD="focal"

# the specific versions will be set later based on INSTALL_TYPE
DEFAULT_INSTALL_TYPE="latest"
INSTALL_TYPE="${INSTALL_TYPE:-$DEFAULT_INSTALL_TYPE}"

PY3_VER_LEGACY="3.8"
PY3_VER_STABLE="3.11"

STABLE_FTS_VERSION="2.0.66"
LEGACY_FTS_VERSION="1.9.9.6"
LATEST_FTS_VERSION=$(curl -s https://pypi.org/pypi/FreeTAKServer/json | python3 -c "import sys, json; print(json.load(sys.stdin)['info']['version'])")

FTS_VENV="${HOME}/fts.venv"

DRY_RUN=0

hsep="*********************"
#
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
# Print out helpful message.
# Outputs:
#   Writes usage message to stdout
###############################################################################
function usage() {
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") [<optional-arguments>]

Install Free TAK Server and components.

Available options:

-h, --help       Print help
-v, --verbose    Print script debug info
-c, --check      Check for compatibility issues while installing
    --core       Install FreeTAKServer, UI, and Web Map
    --latest     [DEFAULT] Install latest version (v$LATEST_FTS_VERSION)
-s, --stable     Install latest stable version (v$STABLE_FTS_VERSION)
-l, --legacy     Install legacy version (v$LEGACY_FTS_VERSION)
    --repo       Replaces with specified ZT Installer repository [DEFAULT ${DEFAULT_REPO}]
    --branch     Use specified ZT Installer repository branch [DEFAULT main]
    --dev-test   Sets TEST Envar to 1
    --dry-run    Sets up dependencies but exits before running any playbooks
    --ip-addr    Explicitly set IP address (when http://ifconfig.me/ip is wrong)
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
  local code=${2-1}
  msg "$msg"

  [[ $code -eq 0 ]] || echo -e "Exiting. Installation NOT successful."

  # default exit status 1
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
      echo "Verbose output"
      set -x

      NO_COLOR=1
      GIT_TRACE=true
      GIT_CURL_VERBOSE=true
      GIT_SSH_COMMAND="ssh -vvv"
      unset APT_VERBOSITY # verbose is the default
      ANSIBLE_VERBOSITY="-vvvvv"

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

    --stable | -s)
      INSTALL_TYPE="stable"
      shift
      ;;

    --latest)
      INSTALL_TYPE="latest"
      shift
      ;;

    --legacy | -l)
      INSTALL_TYPE="legacy"
      shift
      ;;

    -B)
      echo "${RED}${hsep}${hsep}${hsep}"
      echo -e "This option is not supported for public use.\n\
      It will alter the version of this installer, which means:\n\
      1. it may make breaking system alterations\n\
      2. use at your own risk\n\
      It is highly recommended that you do not continue\n\
      unless you've selected this option for a specific reason"
      echo "${hsep}${hsep}${hsep}${NOFORMAT}"
      CBRANCH=$2
      shift 2
      ;;

    --repo)
      REPO=$2
      shift 2

      if [[ -d ~/FreeTAKHub-Installation ]]
        then rm -rf ~/FreeTAKHub-Installation
      fi
      ;;

    --branch)
      BRANCH=$2
      shift 2
      ;;

    --dev-test)
      TEST=1
      shift
      ;;

    --dry-run)
      DRY_RUN=1
      shift
      ;;

    --ip-addr)
      FTS_IP_CUSTOM=$2
      shift 2
      echo "Using the IP of ${FTS_IP_CUSTOM}"
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
# Update variables from defaults, user inputs or implied values
###############################################################################
function set_versions() {
  case $INSTALL_TYPE in
    latest)
      export PY3_VER=$PY3_VER_STABLE
      export FTS_VERSION=$LATEST_FTS_VERSION
      export CFG_RPATH="core/configuration"
      export OS_REQD=$STABLE_OS_REQD
      export OS_VER_REQD=$STABLE_OS_VER_REQD
      export CODENAME=$STABLE_CODENAME_REQD
      ;;
    legacy)
      export PY3_VER=$PY3_VER_LEGACY
      export FTS_VERSION=$LEGACY_FTS_VERSION
      export CFG_RPATH="controllers/configuration"
      export OS_REQD=$LEGACY_OS_REQD
      export OS_VER_REQD=$LEGACY_OS_VER_REQD
      export CODENAME=$LEGACY_CODENAME_REQD
      ;;
    stable)
      export PY3_VER=$PY3_VER_STABLE
      export FTS_VERSION=$STABLE_FTS_VERSION
      export CFG_RPATH="core/configuration"
      export OS_REQD=$STABLE_OS_REQD
      export OS_VER_REQD=$STABLE_OS_VER_REQD
      export CODENAME=$STABLE_CODENAME_REQD
      ;;
    *)
      die "Unsupport install type: $INSTALL_TYPE"
      ;;
  esac

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
    WEBMAP_FORCE_INSTALL="webmap_force_install=true"
  fi

  if [[ -n "${TEST-}" ]]; then
      REPO="https://github.com/janseptaugust/FreeTAKHub-Installation.git"
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

  which apt-get >/dev/null
  if [[ $? -ne 0 ]]; then
    die "Could not locate apt... this installation method will not work"
  fi

  echo -e -n "${BLUE}Checking for supported OS...${NOFORMAT}"

  # freedesktop.org and systemd
  if [[ -f /etc/os-release ]]; then

    . /etc/os-release

    OS=${NAME:-unknown}
    VER=${VERSION_ID:-unknown}
    CODENAME=${VERSION_CODENAME}

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
  if [[ "${OS}" != "${OS_REQD}" ]] || [[ "${VER}" != "${OS_VER_REQD}" ]]; then

    echo -e "${YELLOW}WARNING${NOFORMAT}"
    echo "FreeTAKServer has only been tested on ${GREEN}${OS_REQD} ${OS_VER_REQD}${NOFORMAT}."
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

  else

    echo -e "${GREEN}Success!${NOFORMAT}"
    echo -e "This machine is currently running: ${GREEN}${OS} ${VER}${NOFORMAT}"
    echo -e "Selected install type is: ${GREEN}${DEFAULT_INSTALL_TYPE}"

  fi

}

###############################################################################
# Check for supported architecture
###############################################################################
function check_architecture() {

  echo -e -n "${BLUE}Checking for supported architecture...${NOFORMAT}"

  # check for non-Intel-based architecture here
  arch=$(uname --hardware-platform) # uname is non-portable, but we only target Ubuntu 20.04/22.04
  if ! grep --ignore-case x86 <<<"${arch}" >/dev/null; then

    echo -e "${YELLOW}WARNING${NOFORMAT}"
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
      WEBMAP_FORCE_INSTALL="webmap_force_install=true"
      echo -e "${YELLOW}WARNING${NOFORMAT}: forcing web map installation!"
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

  # dpkg --list | grep -q needrestart && NEEDRESTART=1
  # [[ 0 -eq $NEEDRESTART ]] || apt-get remove --yes needrestart
  x=$(find /etc/apt/apt.conf.d -name "*needrestart*")
  if [[ -f $x ]]; then
    NEEDRESTART=$x
    mv $x $HOME/nr-conf-temp
  fi

  # Some programs need predictable names for certain libraries, so symlink
  x="pkg inst"
  for y in $x; do
	  z=$(find /usr/lib -name apt_${y}.so)
	  if [[ -z $z ]]; then
		  z=$(find /usr/lib -name "apt_${y}.cpython*.so")
		  ln -sf $z $(dirname $z)/apt_${y}.so
	  fi
  done

  # Some Ubuntu installations do not have the software-properties-common
  # package by default, so install it if not installed
  which apt-add-repository >/dev/null || apt-get --yes install software-properties-common

  apt-add-repository -y ppa:ansible/ansible

  echo -e "${BLUE}Downloading package information from configured sources...${NOFORMAT}"

  apt-get -y ${APT_VERBOSITY--qq} update

  echo -e "${BLUE}Installing Ansible...${NOFORMAT}"
  apt-get -y ${APT_VERBOSITY--qq} install ansible

  echo -e "${BLUE}Installing Git...${NOFORMAT}"
  apt-get -y ${APT_VERBOSITY--qq} install git

}

###############################################################################
# We can install the python virtual environment here including the python interpreter.
# This removes any need to deal with any circular requirement between
# the installer, Ansible, and its dependencies (e.g. jinja2) and
# the application being installed, FTS, and its dependencies.
###############################################################################
function install_python_environment() {
  apt-get update
  apt-get install -y python3-pip python3-setuptools
  apt-get install -y python${PY3_VER}-dev python${PY3_VER}-venv libpython${PY3_VER}-dev

  /usr/bin/python${PY3_VER} -m venv ${FTS_VENV}
  source ${FTS_VENV}/bin/activate

  python3 -m pip install --upgrade pip
  python3 -m pip install --force-reinstall jinja2
  python3 -m pip install --force-reinstall pyyaml
  python3 -m pip install --force-reinstall psutil

  deactivate

}
###############################################################################
# Handle git repository
###############################################################################
function handle_git_repository() {

  echo -e -n "${BLUE}Checking for FreeTAKHub-Installation in home directory..."
  cd ~

  [[ -n $CBRANCH ]] && BRANCH=$CBRANCH
  # check for FreeTAKHub-Installation repository
  if [[ ! -d ~/FreeTAKHub-Installation ]]; then

    echo -e "local working git tree NOT FOUND"
    echo -e "Cloning the FreeTAKHub-Installation repository...${NOFORMAT}"
    git clone --branch "${BRANCH}" ${REPO}  ~/FreeTAKHub-Installation

    cd ~/FreeTAKHub-Installation

  else

    echo -e "FOUND"

    cd ~/FreeTAKHub-Installation

    echo -e \
      "Pulling latest from the FreeTAKHub-Installation repository...${NOFORMAT}"
    git pull
    git checkout "${BRANCH}"

  fi

  git pull

}

###############################################################################
# Add passwordless Ansible execution
###############################################################################
function add_passwordless_ansible_execution() {

  echo -e \
    "${BLUE}Adding passwordless Ansible execution for the current user...${NOFORMAT}"

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

  echo -e \
    "${BLUE}Creating a public and private keys if non-existent...${NOFORMAT}"

  # check for public and private keys
  if [[ ! -e ${HOME}/.ssh/id_rsa.pub ]]; then
    # generate keys
    ssh-keygen -t rsa -f "${HOME}/.ssh/id_rsa" -N ""
  fi

}

###############################################################################
# Run Ansible playbook to install
# https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#defining-variables-at-runtime
###############################################################################
function run_playbook() {

  export CODENAME
  export INSTALL_TYPE
  export FTS_VERSION
  env_vars="python3_version=$PY3_VER codename=$CODENAME itype=$INSTALL_TYPE"
  env_vars="$env_vars fts_version=$FTS_VERSION cfg_rpath=$CFG_RPATH fts_venv=${FTS_VENV}"
  [[ -n "${FTS_IP_CUSTOM:-}" ]] && env_vars="$env_vars fts_ip_addr_extra=$FTS_IP_CUSTOM"
  [[ -n "${WEBMAP_FORCE_INSTALL:-}" ]] && env_vars="$env_vars $WEBMAP_FORCE_INSTALL"
  [[ -n "${CORE:-}" ]] && pb=install_mainserver || pb=install_all
  echo -e "${BLUE}Running Ansible Playbook ${GREEN}$pb${BLUE}...${NOFORMAT}"
  ansible-playbook -u root  ${pb}.yml \
      --connection=local \
      --inventory localhost, \
      --extra-vars "$env_vars" \
      ${ANSIBLE_VERBOSITY-}
}

function cleanup() {
  if [[ -n $NEEDRESTART ]]
  then
      cp $HOME/nr-conf-temp $NEEDRESTART
  fi
}
###############################################################################
# MAIN BUSINESS LOGIC HERE
###############################################################################

setup_colors
parse_params "${@}"
set_versions
check_os
# do_checks
download_dependencies
[[ "$DEFAULT_INSTALL_TYPE" == "$INSTALL_TYPE" ]] && install_python_environment
handle_git_repository
add_passwordless_ansible_execution
generate_key_pair

[[ 0 -eq $DRY_RUN ]] || die "Dry run complete. Not running Ansible" 0
run_playbook
cleanup
