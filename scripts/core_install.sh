#!/usr/bin/env bash

# set failfast
set -o errexit

# used for calculating execution time
start=$(date +%s)

# quiet by default
REDIRECT=/dev/null

# console coloring is on by default
COLOR_SWITCH=/dev/stdout

# check if user is root
if [[ "$EUID" -ne 0 ]]; then
	printf "%s is not running as root (use sudo).\n" "$0"
	exit 1
fi

trap cleanup SIGINT SIGTERM ERR EXIT INT

SYSTEM_NAME=$(uname)
SYSTEM_DIST="Unknown"
SYSTEM_DIST_BASED_ON="Unknown"
SYSTEM_PSEUDO_NAME="Unknown"
SYSTEM_VERSION="Unknown"
SYSTEM_ARCH=$(uname -m)
SYSTEM_ARCH_NAME="Unknown"
SYSTEM_KERNEL=$(uname -r)
SYSTEM_CONTAINER=false
CLOUD_PROVIDER="n/a"

# system-related variables
readonly user_exec="sudo -i -u $SUDO_USER"
readonly group_name="fts"
readonly venv_name="fts"
readonly python_version="3.8"

# fts variables
readonly fts_package="FreeTAKServer"
readonly fts_config_file="FTSConfig.yaml"
readonly fts_service=fts

# fts ui variables
readonly fts_ui_package="FreeTAKServer-UI"
readonly fts_ui_config_file="config.py"
readonly fts_ui_service=fts-ui

# webmap variables
readonly webmap_name="FTH-webmap-linux"
readonly webmap_version="0.2.5"
readonly webmap_filename="$webmap_name-$webmap_version.zip"
readonly webmap_executable="$webmap_name-$webmap_version"
readonly webmap_url="https://github.com/FreeTAKTeam/FreeTAKHub/releases/download/v$webmap_version/$webmap_name-$webmap_version.zip"
readonly webmap_sha256="11afcde545cc4c2119c0ff7c89d23ebff286c99c6e0dfd214eae6e16760d6723"
readonly webmap_config_file="webMAP_config.json"
readonly webmap_service=webmap

cleanup() {
	trap - SIGINT SIGTERM ERR EXIT INT
	rm -f "$conda_installer"
	rm -f "$webmap_zip"
}

# home directory of user running this script
user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6) || false

# unless specified, default target IPv4 is localhost
my_ipv4="127.0.0.1"

declare -a supported_os=(
	"ubuntu 20.04"
)

usage() {
	cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]:-}") [<optional-arguments>]

Install FreeTAKServer (FTS) which includes: fts, ui, and webmap.

Available options:
-h, --help          print help
-v, --verbose       print script debug info
-l, --log           log output to file named fts.log (in running directory)
    --no-color      turn off console colors

===============================================================================
NETWORKING OPTIONS
===============================================================================
If none of the below options are set, the IPv4 will be localhost.

  -i, --ipv4=IPV4   If set, fts will use this IPv4.

===============================================================================
EXAMPLES
===============================================================================
Install freetakserver (fts) core components: fts, user interface, and webmap.

        sudo ./easy_install

Install using a specific ipv4:

        sudo ./easy_install --ipv4 161.31.208.79

Install fts with log and verbosity. Creates a fts.log file in running directory.

        sudo ./easy_install -v -l

USAGE_TEXT
	exit 1
}

####################################################################### LOGGING
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_OFF="\033[0m"

print_timestamp() {
	local timestamp
	if [[ -n $VERBOSE ]]; then
		timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
		printf '[%s]' "$timestamp"
	fi

}

color_off() {
	printf '%b' "$COLOR_OFF" &>$COLOR_SWITCH
}

color_on() {
	local color="$1"
	printf '%b' "$color" &>$COLOR_SWITCH
}

print_error() {
	{
		print_timestamp
		color_on "$COLOR_RED"
		printf '[ERROR] '
		color_off
		print_msg "$@"
	} >&2
}

print_warn() {
	print_timestamp
	color_on "$COLOR_YELLOW"
	printf '[WARN]  '
	color_off
	print_msg "$@"
}

print_info() {
	print_timestamp
	color_on "$COLOR_GREEN"
	printf '[INFO]  '
	color_off
	print_msg "$@"
}

print_debug() {
	if [[ -n $VERBOSE ]]; then
		print_timestamp
		color_on "$COLOR_BLUE"
		printf '[DEBUG] '
		color_off
		printf '%s\n' "$@"
	fi
}

print_msg() {
	printf '%s\n' "$@"
}

setup_log() {
	exec > >(tee fts.log) 2>&1
}

################################################################## LIB FUNCTIONS

validate_ipv4() {
	# check if $candidate_ip is a valid my_ipv4 address
	# return 0 if true, 1 otherwise
	local -A params=([candidate_ip]="$1")
	print_debug "------------------------"
	print_debug_table "VALIDATING IPv4: " params

	local arr element
	IFS=. read -r -a arr <<<"${params[candidate_ip]}"
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
	if [[ ("$result" -eq "1") ]]; then
		print_error "INVALID IPv4" "$candidate_ipv4"
		exit 1
	fi
}

ensure_permissions() {
	chown -R :"$group_name" "$conda_install_dir"
	chmod -R g=rwx "$conda_install_dir"
}

print_debug_table() {
	# don't print messy table if logger is on
	if [[ -z $LOGGER_ON ]]; then
		local title="$1"
		local -n content="$2"
		local rows
		print_debug "$title"

		rows="key,value\n"
		for key in "${!content[@]}"; do
			rows+="$key, ${content[$key]}\n"
		done
		table=$(
			cat <<EOF
$rows
EOF
		)

		printTable ',' "$(echo $table)" | format_subshell_output
	fi

}

replace() {
	# global replacement of string in file
	local -A params=([file]="$1" [search]="$2" [replace]="$3")
	print_debug "------------------------"
	print_debug_table "REPLACING LINE IN FILE: " params
	sed -i "s/${params[search]}/${params[replace]}/g" "${params[file]}"
}

basename() {
	# Usage: basename "path" ["suffix"]

	# Strip all trailing forward-slashes '/' from
	# the end of the string.
	#
	# "${1##*[!/]}": Remove all non-forward-slashes
	# from the start of the string, leaving us with only
	# the trailing slashes.
	# "${1%%"${}"}:  Remove the result of the above
	# substitution (a string of forward slashes) from the
	# end of the original string.
	dir=${1%${1##*[!/]}}

	# Remove everything before the final forward-slash '/'.
	dir=${dir##*/}

	# If a suffix was passed to the function, remove it from
	# the end of the resulting string.
	dir=${dir%"$2"}

	# Print the resulting string and if it is empty,
	# print '/'.
	printf '%s\n' "${dir:-/}"
}

function printTable() {
	local -r delimiter="${1}"
	local -r data="$(removeEmptyLines "${2}")"

	if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]; then
		local -r numberOfLines="$(wc -l <<<"${data}")"

		if [[ "${numberOfLines}" -gt '0' ]]; then
			local table=''
			local i=1

			for ((i = 1; i <= "${numberOfLines}"; i = i + 1)); do
				local line=''
				line="$(sed "${i}q;d" <<<"${data}")"

				local numberOfColumns='0'
				numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<<"${line}")"

				# Add Line Delimiter
				if [[ "${i}" -eq '1' ]]; then
					table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
				fi

				# Add Header Or Body
				table="${table}\n"
				local j=1
				for ((j = 1; j <= "${numberOfColumns}"; j = j + 1)); do
					table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<<"${line}")")"
				done
				table="${table}#|\n"

				# Add Line Delimiter
				if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]; then
					table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
				fi
			done

			if [[ "$(isEmptyString "${table}")" = 'false' ]]; then
				echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
			fi
		fi
	fi
}

function removeEmptyLines() {
	local -r content="${1}"
	echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString() {
	local -r string="${1}"
	local -r numberToRepeat="${2}"
	if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]; then
		local -r result="$(printf "%${numberToRepeat}s")"
		echo -e "${result// /${string}}"
	fi
}

function isEmptyString() {
	local -r string="${1}"
	if [[ "$(trimString "${string}")" = '' ]]; then
		echo 'true' && return 0
	fi
	echo 'false' && return 1
}

function trimString() {
	local -r string="${1}"
	sed 's,^[[:blank:]]*,,' <<<"${string}" | sed 's,[[:blank:]]*$,,'
}

download() {
	# download file with wget
	local -A params=([url]="$1" [dest]="$2")
	print_debug "------------------------"
	print_debug_table "DOWNLOADING: " params
	wget "${params[url]}" -qO "${params[dest]}"
}

check_file_integrity() {
	local -A params=([checksum]="$1" [file]="$2")
	print_debug "------------------------"
	print_debug_table "CHECKING FILE INTEGRITY: " params
	SHA256SUM_RESULT=$(printf "%s %s" "${params[checksum]}" "${params[file]}" | sha256sum -c)
	if [ ! "${SHA256SUM_RESULT}" = "${params[file]}: OK" ]; then
		exit 0
	fi
}

format_subshell_output() {
	while IFS= read -r line; do
		print_debug "$line" &>$REDIRECT
	done
}

setup_service() {
	local -A params=([name]="$1" [command]="$2")
	print_debug "------------------------"
	print_debug_table "SETTING UP SERVICE: " params
	create_start_script "${params[name]}" "${params[command]}"
	create_unit_file "${params[name]}"
	mv -f "${params[name]}.sh" "$script_files_dir/${params[name]}.sh"
	mv -f "${params[name]}.service" "$unit_files_dir/${params[name]}.service"
	ensure_permissions
	enable_service "${params[name]}"
}

enable_service() {
	local name=$1
	chown -R :"$group_name" "$conda_install_dir"
	chown -R :"$group_name" "/var/log"
	chmod -R g+rw "$conda_install_dir"
	chmod -R g+rw "/var/log"
	$conda_run systemctl daemon-reload
	$conda_run systemctl enable "$name"
}

is_webmap_compatible() {
	modelname=$(cat /proc/cpuinfo | grep 'model name' | head -1)
	if grep -i intel <<<"$modelname"; then
		return 0
	fi
	return 1
}

create_conda_env() {
	cat <<EOF >"/tmp/environment.yml"
name: fts
channels:
  - defaults
dependencies:
  - _libgcc_mutex=0.1=main
  - _openmp_mutex=4.5=1_gnu
  - ca-certificates=2022.4.26=h06a4308_0
  - certifi=2021.10.8=py38h06a4308_2
  - ld_impl_linux-64=2.35.1=h7274673_9
  - libffi=3.3=he6710b0_2
  - libgcc-ng=9.3.0=h5101ec6_17
  - libgomp=9.3.0=h5101ec6_17
  - libstdcxx-ng=9.3.0=hd4cf53a_17
  - ncurses=6.3=h7f8727e_2
  - openssl=1.1.1n=h7f8727e_0
  - pip=21.2.4=py38h06a4308_0
  - python=3.8.13=h12debd9_0
  - readline=8.1.2=h7f8727e_1
  - setuptools=61.2.0=py38h06a4308_0
  - sqlite=3.38.2=hc218d9a_0
  - tk=8.6.11=h1ccaba5_0
  - unzip=6.0=h611a1e1_0
  - wheel=0.37.1=pyhd3eb1b0_0
  - xz=5.2.5=h7f8727e_1
  - zlib=1.2.12=h7f8727e_2
  - pip:
    - alembic==1.7.7
    - bcrypt==3.1.7
    - cffi==1.15.0
    - charset-normalizer==2.0.12
    - click==8.0.4
    - colorama==0.4.4
    - cryptography==36.0.2
    - defusedxml==0.7.1
    - dnspython==1.16.0
    - email-validator==1.2.1
    - eventlet==0.29.0
    - flask==1.1.2
    - flask-cors==3.0.9
    - flask-httpauth==4.2.0
    - flask-login==0.5.0
    - flask-migrate==3.1.0
    - flask-socketio==4.3.1
    - flask-sqlalchemy==2.4.4
    - flask-wtf==1.0.1
    - freetakserver==1.9.9.4
    - freetakserver-ui==1.9.9.2
    - geographiclib==1.52
    - geopy==2.2.0
    - greenlet==1.1.2
    - gunicorn==20.1.0
    - idna==3.3
    - importlib-metadata==4.11.3
    - importlib-resources==5.7.1
    - itsdangerous==2.0.1
    - jinja2==2.11.2
    - lxml==4.6.5
    - mako==1.2.0
    - markupsafe==2.0.1
    - monotonic==1.6
    - pathlib2==2.3.7.post1
    - pbr==5.8.1
    - pillow==9.1.0
    - protobuf==3.14.0
    - psutil==5.9.0
    - pycparser==2.21
    - pykml==0.2.0
    - pyopenssl==22.0.0
    - python-decouple==3.6
    - python-engineio==3.13.2
    - python-socketio==4.6.0
    - pyyaml==6.0
    - qrcode==7.3.1
    - requests==2.27.1
    - ruamel-yaml==0.17.21
    - ruamel-yaml-clib==0.2.6
    - six==1.16.0
    - sqlalchemy==1.3.20
    - sqlalchemy-utils==0.38.2
    - tabulate==0.8.7
    - testresources==2.0.1
    - urllib3==1.26.9
    - werkzeug==2.0.3
    - wtforms==2.3.3
    - zipp==3.8.0

EOF
}

create_start_script() {
	local name="$1" command="$2"
	cat >"${name}.sh" <<-EOF
		#!/bin/bash

		source $conda_install_dir/etc/profile.d/conda.sh
		conda activate $venv_name
		$command

	EOF
}

create_unit_file() {
	local name="$1"
	cat >"${name}.service" <<-EOF
		[Unit]
		Description=${name} service
		After=network.target
		StartLimitIntervalSec=0

		[Service]
		Type=simple
		Restart=always
		RestartSec=1
		StandardOutput=append:$CONDA_PREFIX/logs/${name}-stdout.log
		StandardError=append:$CONDA_PREFIX/logs/${name}-stderr.log
		WorkingDirectory=${script_files_dir}
		ExecStart=${script_files_dir}/${name}.sh

		[Install]
		WantedBy=multi-user.target

	EOF
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
    IP = '$my_ipv4'

    # Port the  UI uses to communicate with the API
    PORT = '19023'

    # the public IP your server is exposing
    APPIP = '$my_ipv4'

    # webmap IP
    WEBMAPIP = '$my_ipv4'

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

############################################################### FTS INSTALLATION

identify_system() {

	# detect Debian family
	if [ -f /etc/debian_version ]; then
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

		# detect macOS
	elif uname -s | grep -iq "darwin"; then
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

		# detect RedHat family
	elif [ -f /etc/redhat-release ]; then
		SYSTEM_DIST=$(sed s/\ release.*// /etc/redhat-release | tr "[:upper:]" "[:lower:]")
		echo "$SYSTEM_DIST" | grep -q "red" && SYSTEM_DIST="redhat"
		echo "$SYSTEM_DIST" | grep -q "centos" && SYSTEM_DIST="centos"
		SYSTEM_DIST_BASED_ON="redhat"
		SYSTEM_PSEUDO_NAME=$(sed s/.*\(// /etc/redhat-release | sed s/\)//)
		SYSTEM_VERSION=$(sed s/.*release\ // /etc/redhat-release | sed s/\ .*//)
		SYSTEM_ARCH_NAME="i386"
		uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
		{ uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"

		# detect Alpine
	elif which apk >/dev/null 2>&1; then
		SYSTEM_DIST="alpine"
		SYSTEM_DIST_BASED_ON="alpine"
		SYSTEM_PSEUDO_NAME=
		SYSTEM_VERSION=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+' /etc/alpine-release)
		SYSTEM_ARCH_NAME="i386"
		uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
		{ uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"

		# detect Busybox
	elif which busybox >/dev/null 2>&1; then
		SYSTEM_DIST="busybox"
		SYSTEM_DIST_BASED_ON="busybox"
		SYSTEM_PSEUDO_NAME=
		SYSTEM_VERSION=$(busybox | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
		SYSTEM_ARCH_NAME="i386"
		uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
		{ uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"

		# detect Amazon Linux
	elif grep -iq "amazon linux" /etc/os-release 2>/dev/null; then
		SYSTEM_DIST="amazon"
		SYSTEM_DIST_BASED_ON="redhat"
		SYSTEM_PSEUDO_NAME=
		SYSTEM_VERSION=$(grep "^VARIANT_ID=" /etc/os-release | awk -F= '{ print $2 }' | sed s/\"//g)
		[ -z "$SYSTEM_VERSION" ] && SYSTEM_VERSION=$(grep "^VERSION_ID=" /etc/os-release | awk -F= '{ print $2 }' | sed s/\"//g)
		SYSTEM_ARCH_NAME="i386"
		uname -m | grep -q "64" && SYSTEM_ARCH_NAME="amd64"
		{ uname -m | grep -q "arm[_]*64" || uname -m | grep -q "aarch64"; } && SYSTEM_ARCH_NAME="arm64"
	fi

	# detect docker container
	if grep -iq docker /proc/1/cgroup 2>/dev/null || head -n 1 /proc/1/sched 2>/dev/null | grep -Eq '^(bash|sh) ' || [ -f /.dockerenv ]; then
		SYSTEM_CONTAINER="true"
	fi

	# detect cloud provider
	# DigitalOcean
	if dmidecode --string "bios-vendor" | grep -iq "digitalocean"; then
		CLOUD_PROVIDER="digitalocean"

		# Amazon Web Services
	elif dmidecode -s bios-version | grep -iq "amazon"; then
		CLOUD_PROVIDER="amazon"

		# Microsoft Azure
	elif dmidecode -s system-manufacturer | grep -iq "microsoft corporation"; then
		CLOUD_PROVIDER="azure"

		# Google Cloud Platform
	elif dmidecode -s bios-version | grep -iq "google"; then
		CLOUD_PROVIDER="google"

		# Oracle Cloud Infrastructure
	elif dmidecode -s bios-version | grep -iq "ovm"; then
		CLOUD_PROVIDER="oracle"
	fi

	SYSTEM_NAME=$(echo "$SYSTEM_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
	SYSTEM_DIST=$(echo "$SYSTEM_DIST" | tr "[:upper:]" "[:lower:]" | tr " " "_")
	SYSTEM_DIST_BASED_ON=$(echo "$SYSTEM_DIST_BASED_ON" | tr "[:upper:]" "[:lower:]" | tr " " "_")
	SYSTEM_PSEUDO_NAME=$(echo "$SYSTEM_PSEUDO_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
	SYSTEM_VERSION=$(echo "$SYSTEM_VERSION" | tr "[:upper:]" "[:lower:]" | tr " " "_")
	SYSTEM_ARCH=$(echo "$SYSTEM_ARCH" | tr "[:upper:]" "[:lower:]" | tr " " "_")
	SYSTEM_ARCH_NAME=$(echo "$SYSTEM_ARCH_NAME" | tr "[:upper:]" "[:lower:]" | tr " " "_")
	SYSTEM_KERNEL=$(echo "$SYSTEM_KERNEL" | tr "[:upper:]" "[:lower:]" | tr " " "_")

	local is_supported=false

	print_debug "list of supported operating systems: "

	# check for supported os
	for candidate_os in "${supported_os[@]}"; do
		local supported_os_version="$SYSTEM_DIST $SYSTEM_VERSION"
		print_debug "    $supported_os_version"
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
	print_info "detected supported os: $candidate_os"

	print_debug "detecting compatible architecture for webmap"
	set +e # don't failfast when checking
	result=$(printf is_webmap_compatible)
	set -e # turn failfast back on
	if [[ $result -eq 0 ]]; then
		webmap_compatible=true
		print_debug "Webmap is supported on Intel-based processors. Your processor is webmap compatible."
		full_modelname=$(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d':' -f2 | xargs)
		print_info "detected compatible architecture for webmap: $full_modelname"
	else
		webmap_compatible=false
		print_warn "Webmap is supported on Intel-based processors."
		print_warn "Intel processor NOT detected."
		print_warn "Webmap installation/execution may fail."
	fi
}

setup_virtual_environment() {
	conda_filename="Miniconda3-py38_4.11.0-Linux-x86_64.sh"
	local conda_installer=$(mktemp --suffix ".$conda_filename") || false
	conda_url="https://repo.anaconda.com/miniconda/$conda_filename"
	conda_sha256="4bb91089ecc5cc2538dece680bfe2e8192de1901e5e420f63d4e78eb26b0ac1a"

	# download conda
	conda_install_dir="$user_home/conda"
	download $conda_url "$conda_installer" &>$REDIRECT
	check_file_integrity "$conda_sha256" "$conda_installer" &>$REDIRECT

	mkdir -p "$conda_install_dir"

	bash "$conda_installer" -u -b -p "$conda_install_dir" | format_subshell_output

	print_debug "installed virtual environment"

	groupadd -f "$group_name"
	usermod -a -G "$group_name" "$SUDO_USER"
	chgrp "$group_name" "/usr/local/bin"
	ln -sf "$conda_install_dir/bin/conda" "/usr/local/bin/conda"
	print_debug "set permissions for virtual environment"

	source "$conda_install_dir/etc/profile.d/conda.sh"
	conda update --yes --name base conda | format_subshell_output
	conda config --set auto_activate_base true --set always_yes yes --set changeps1 yes
	print_debug "configured conda virtual environment"

	conda create --name "$venv_name" python="$python_version" | format_subshell_output
	print_debug "created virtual environment: $venv_name"

	$user_exec conda init bash | format_subshell_output
	eval "$(conda shell.bash hook)"
	conda activate "$venv_name"
	print_debug "activated virtual environment"

	# set conda/python variables to facilitate later steps
	conda_run="conda run -n $venv_name"
	python_exec=$($conda_run which python)
	sitepackages="$CONDA_PREFIX/lib/python${python_version}/site-packages"
	unit_files_dir="/lib/systemd/system"
	script_files_dir="$conda_install_dir/etc/profile.d"

	ensure_permissions
	print_info "installed virtual environment"
}

fts_shell_install() {
	fts_config_destination="$CONDA_PREFIX/$fts_config_file"

	# change first_start to False in MainConfig.py
	local search="    first_start = True"
	local replace="    first_start = False"
	fts_mainconfig_file="$sitepackages/$fts_package/controllers/configuration/MainConfig.py"
	replace "$fts_mainconfig_file" "$search" "$replace"

	# configure FTSConfig.yaml
	initialize_fts_yaml
	chgrp "$group_name" "/tmp/$fts_config_file"
	mv -f "/tmp/$fts_config_file" "$fts_config_destination"
	print_debug "configured fts"

	print_info "installed fts"
}

fts_ui_shell_install() {
	fts_ui_config_destination="$sitepackages/$fts_ui_package/config.py"
	print_debug "configuring fts ui"
	initialize_fts_ui_config
	chgrp "$group_name" "/tmp/$fts_ui_config_file"
	mv -f "/tmp/$fts_ui_config_file" "$fts_ui_config_destination"
	print_info "installed fts ui"
}

webmap_shell_install() {

	webmap_install_dir="$CONDA_PREFIX/bin"
	webmap_config_destination="$CONDA_PREFIX/webMAP_config.json"

	ensure_permissions

	print_debug "downloading webmap"
	wget $webmap_url -qO "/tmp/$webmap_filename"
	check_file_integrity "$webmap_sha256" "/tmp/$webmap_filename"

	print_debug "installing webmap"

	# unzip webmap
	chmod 777 "/tmp/$webmap_filename"
	$user_exec conda install -y --name "$venv_name" unzip | format_subshell_output
	$conda_run unzip -o "/tmp/$webmap_filename" -d /tmp | format_subshell_output

	# remove version string
	mv -f "/tmp/$webmap_executable" "/tmp/$webmap_name"

	# move webmap executable to destination directory
	chgrp "$group_name" "/tmp/$webmap_name"
	mv -f "/tmp/$webmap_name" "$webmap_install_dir/$webmap_name"

	print_debug "configuring webmap"

	print_debug "configuring $webmap_config_file"
	local search="204.48.30.216"
	local replace="$my_ipv4"
	replace "/tmp/$webmap_config_file" "$search" "$replace"
	chgrp "$group_name" "/tmp/$webmap_config_file"

	print_debug "moving /tmp/webMAP_config.json to $webmap_config_destination"
	mv -f "/tmp/$webmap_config_file" "$webmap_config_destination"

	print_info "installed webmap"
}

install_components() {
	create_conda_env
	conda env update -n "$venv_name" --file "/tmp/environment.yml" | format_subshell_output
	ensure_permissions
	fts_shell_install
	fts_ui_shell_install
	webmap_shell_install
	ensure_permissions
}

enable_services() {
	print_debug "set fts to autostart"
	fts_command="$python_exec -u -m FreeTAKServer.controllers.services.FTS"
	setup_service "$fts_service" "$fts_command"

	print_debug "set fts ui to autostart"
	fts_ui_command="$python_exec  $sitepackages/$fts_ui_package/run.py"
	setup_service "$fts_ui_service" "$fts_ui_command"

	print_debug "setting up webmap to autostart"
	webmap_command="$webmap_install_dir/$webmap_name $webmap_config_destination"
	setup_service "$webmap_service" "$webmap_command"

	chgrp -R "$group_name" "/var/log"
}

start_services() {
	ensure_permissions
	$conda_run systemctl start "$fts_service"
	$conda_run systemctl start "$fts_ui_service"
	$conda_run systemctl start "$webmap_service"
}

########################################################## CONFIGURATION SUMMARY

print_config() {
	fts_config_summary_location="$CONDA_PREFIX/fts_config_summary.txt"
	VERSIONS=$(
		cat <<-EOF
			VERSION ITEM, VALUE\n
			fts version, $(pip show freetakserver | grep -i version | awk '{print $2, $3}' | cut -d':' -f2)\n
			fts ui version, $(pip show freetakserver-ui | grep -i version | awk '{print $2, $3}' | cut -d':' -f2)\n
			webmap version, $webmap_version\n
			conda version, $(conda --version | cut -d ' ' -f2)\n
		EOF
	)

	SYSTEM_CONFIG=$(
		cat <<-EOF
			SYSTEM ITEM, VALUE\n
			kernel name, $SYSTEM_NAME\n
			os distribution,  $SYSTEM_DIST\n
			os family,  $SYSTEM_DIST_BASED_ON\n
			os name,  $SYSTEM_PSEUDO_NAME\n
			os version,  $SYSTEM_VERSION\n
			machine hardware name,  $SYSTEM_ARCH\n
			architecture name,  $SYSTEM_ARCH_NAME\n
			kernel release,  $SYSTEM_KERNEL\n
			inside container,  $SYSTEM_CONTAINER\n
			cloud provider,  $CLOUD_PROVIDER\n
			total cores, $(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)\n
			total ram, $(free -m | awk '/Mem/ {print $2}') MB\n
			total swap, $(free -m | awk '/Swap/ {print $2}') MB\n
		EOF
	)

	FTS_CONFIG=$(
		cat <<-EOF
			CONFIG ITEM, VALUE\n
			installed for user, $SUDO_USER\n
			group, $group_name\n
			unit files directory, $unit_files_dir\n
			virtual environment path, $CONDA_PREFIX\n
			python site-packages directory, $sitepackages\n
			MainConfig.py location, $fts_mainconfig_file\n
			FTS_Config.yaml location, $fts_config_destination\n
			webmap install location, $webmap_install_dir/$webmap_name\n
			fts start command, $fts_command\n
			fts ui start command, $fts_ui_command\n
			webmap start command, $webmap_command\n
			fts start script, $script_files_dir/${fts_service}.sh\n
			fts ui start script, $script_files_dir/${fts_ui_service}.sh\n
			webmap start script, $script_files_dir/${webmap_service}.sh\n
			activate virtual environment command, conda activate $venv_name\n
		EOF
	)

	NETWORK_CONFIG=$(
		cat <<-EOF
			NETWORK ITEM, VALUE\n
			fts ipv4, $my_ipv4\n
			fts ui ipv4, $my_ipv4\n
			webmap ipv4, $my_ipv4\n
		EOF
	)

	WARN=$(
		cat <<-EOF
			WARNING ITEM, VALUE\n
			webmap compatible?, $webmap_compatible\n
		EOF
	)

	{
		printTable ',' "$(echo $VERSIONS)"
		printTable ',' "$(echo $SYSTEM_CONFIG)"
		printTable ',' "$(echo $FTS_CONFIG)"
		printTable ',' "$(echo $NETWORK_CONFIG)"
		printTable ',' "$(echo $WARN)"
	} >&1 | tee "$fts_config_summary_location"
	printf "configuration summary saved to: $fts_config_summary_location\n"
}

############################################################ MAIN BUSINESS LOGIC

while true; do
	case "${1-}" in
	--help | -h)
		usage
		exit 0
		shift
		;;
	--no-color)
		COLOR_SWITCH=/dev/null
		shift
		;;
	--log | -l)
		LOGGER_ON=1
		setup_log
		set -x
		shift
		;;
	--verbose | -v)
		VERBOSE=1
		REDIRECT=/dev/stdout
		shift
		;;
	--ipv4)
		candidate_ipv4=$2
		check_ipv4_arg "$candidate_ipv4"
		my_ipv4="$candidate_ipv4"
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
identify_system
setup_virtual_environment
install_components
enable_services
start_services
print_config
end=$(date +%s)
total_seconds=$((end - start))
printf "SUCCESS! INSTALLED IN %ss.\n" "$total_seconds"
printf "LAUNCH FTS VIRTUAL ENVIRONMENT:\n"
printf "conda activate %s\n" "$venv_name"
