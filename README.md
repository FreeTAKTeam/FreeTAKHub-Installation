![CI](https://github.com/FreeTAKTeam/FreeTAKHub-Installation/actions/workflows/ci.yml/badge.svg)

# Quick Install (Run On New **Ubuntu 20.04** Image)

Use a clean Ubuntu **20.04** image when installing.

Download Ubuntu 20.04 here: <https://ubuntu.com/download/desktop>

FreeTAKTeam is currently testing on other Operating Systems and distributions.

## Zero Touch Deployment 

```console
wget -qO - bit.ly/ftszerotouch | sudo bash 
```

```console
Available options:

-h, --help       Print help
-v, --verbose    Print script debug info
-c, --check      Check for compatibility issues while installing
    --core       Install FreeTAKServer, UI, and Web Map
```

### Examples

Install core fts components only
```console
wget -qO - bit.ly/ftszerotouch | sudo bash -s -- --core
```

Display help screen
```console
wget -qO - bit.ly/ftszerotouch | sudo bash -s -- -h
```

Do compatibility checks and print more output
```console
wget -qO - bit.ly/ftszerotouch | sudo bash -s -- -c -v
```

## Install Specific Components (Advanced)

```console
wget -qO - bit.ly/ftsadvancedinstall | sudo bash 
```

```console
Available options:

-h,   --help               Print help
-v,   --verbose            Print script debug info
-c,   --check              Check for compatibility issues while installing
      --non-interactive    Assume defaults (non-interactive)
      --core               Install FreeTAKServer, UI, and Web Map
      --nodered            Install Node-RED Server
      --video              Install Video Server
      --mumble             Install Murmur VOIP Server and Mumble Client
```

### Examples

Install core and nodered non-interactively (do not prompt for user input).

```console
wget -qO - bit.ly/ftsadvancedinstall | sudo bash -s -- --core --nodered --non-interactive
```

Do compatibility checks, print more output, and prompt for installing other components.

```console
wget -qO - bit.ly/ftsadvancedinstall | sudo bash -s -- -c -v
```

Install video and mumble, but prompt to install for other components.

```console
wget -qO - bit.ly/ftsadvancedinstall | sudo bash -s -- --video --mumble
```

# FreeTAKHub Installation

This script will install and configure these components:

1. FreeTAKServer (FTS): The core server that interfaces with TAK-enabled clients
1. FreeTAKServer User Interface (FTS-UI): A web-based user interface.
1. FreeTAKHub Webmap: A mapping component on the web interface.
1. Video Server:  Handles video streaming.
1. FreeTAKHub Server: Handles FTS integrations like SALUTE reports & video checking services (checks if videos are running and notifies FTS).
1. FreeTAKHub Voice Server: Uses [Murmur](https://github.com/mumble-voip/mumble) or Mumble VOIP Server for voice chatting.

# Zero Touch Deployment Diagram

![image](https://user-images.githubusercontent.com/60719165/159137165-59164055-ce6d-4396-9a9b-f7503d20b3f6.png)



# Install FreeTAKHub with Ansible

This repository includes Ansible roles to:

- create the target nodes.
- install FTS and additional modules.
- configure FTS.

## Windows Prerequisites

Below is required for Windows machines.

The machine must be running: Windows 10 Version 2004 or higher (Build 19041 or higher) or Windows 11.

For Windows installations:

1. Install WSL2.

    See: <https://docs.microsoft.com/en-us/windows/wsl/install>

    See also: <https://www.omgubuntu.co.uk/how-to-install-wsl2-on-windows-10>

    See also: <https://www.sitepoint.com/wsl2/>

1. Install the WSL Ubuntu 20.04 distribution.

    See: <https://www.microsoft.com/en-us/p/ubuntu-2004-lts/9n6svws3rx71>

## Step 1. Clone the `FreeTAKHub-Installation` repository

In the console:

```console
sudo apt update
```

Make sure you have `git` installed:

```console
sudo apt install -y git
```

Go to the home directory:

```console
cd ~
```

Clone the `FreeTAKHub-Installation` repository:

```console
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
```

Go to the top-level directory of the `FreeTAKHub-Installation` repository:

```console
cd FreeTAKHub-Installation
```

If you have previously cloned the repository, update the repository:

```console
git pull
```

## Step 2. Install Ansible

### Automated Ansible Installation

At the top-level directory of the `FreeTAKHub-Installation` repository, enter:

```console
./scripts/init.sh
```

Optional (But Recommended!): Activate the Python virtual environment:

```console
activate
```

To deactivate the Python virtual environment:

```console
deactivate
```

To learn more about Python virtual environments and why they are a good idea, see:

<https://realpython.com/python-virtual-environments-a-primer/>

### Manual Ansible Installation
 
The manual installation allows more control.

In the console, enter:

```console
sudo apt update
```

```console
sudo apt -y install software-properties-common
```

```console
sudo add-apt-repository --y --update ppa:ansible/ansible
```

```console
sudo apt install -y ansible
```

See: <https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-ubuntu>

## Step 3. Install FreeTAKServer and Components

Go to the top-level directory of the `FreeTAKHub-Installation` repository:

```console
cd ~/FreeTAKHub-Installation
```

Run the Ansible playbook to install FreeTAKServer and components:

```console
sudo ansible-playbook install_all.yml
```

## Checking Your Installation

### Check FreeTAKServer

Open a web browser to:

```
http://<YOUR_IP_ADDRESS>:5000/
```

- login with your credentials
- immediately change the password 
- check whether services are OK (blue)
![image](https://user-images.githubusercontent.com/60719165/148986287-0c83aa3f-e909-4b38-bc81-d66cddb08f89.png)
- connect a client to the server
- click on the WEBMAP button
- confirm the client is connected in the WEBMAP

#### Check The Video Server

Open a web browser to:

```
http://<YOUR_IP_ADDRESS>:9997/v1/config/get
```

Confirm the configuration (which is in `json` format):

```json
{
  "logLevel": "info",
  "logDestinations": [
    "stdout"
  ],
  "logFile": "rtsp-simple-server.log",
  "readTimeout": "10s",
  "writeTimeout": "10s",
  "readBufferCount": 512,
  "api": true,
  "apiAddress": "<YOUR_IP_ADDRESS>:9997",
  "metrics": false,
  "metricsAddress": "127.0.0.1:9998",
  "pprof": false,
  "pprofAddress": "127.0.0.1:9999",
  "runOnConnect": "",
  "runOnConnectRestart": false,
  "rtspDisable": false,
  "protocols": [
    "multicast",
    "tcp",
    "udp"
  ],
  "encryption": "no",
  "rtspAddress": ":8554",
  "rtspsAddress": ":8555",
  "rtpAddress": ":8000",
  "rtcpAddress": ":8001",
  "multicastIPRange": "224.1.0.0/16",
  "multicastRTPPort": 8002,
  "multicastRTCPPort": 8003,
  "serverKey": "server.key",
  "serverCert": "server.crt",
  "authMethods": [
    "basic",
    "digest"
  ],
  "readBufferSize": 2048,
  "rtmpDisable": false,
  "rtmpAddress": ":1935",
  "hlsDisable": false,
  "hlsAddress": ":8888",
  "hlsAlwaysRemux": false,
  "hlsSegmentCount": 3,
  "hlsSegmentDuration": "1s",
  "hlsAllowOrigin": "*",
  "paths": {
    "~^.*$": {
      "source": "publisher",
      "sourceProtocol": "automatic",
      "sourceAnyPortEnable": false,
      "sourceFingerprint": "",
      "sourceOnDemand": false,
      "sourceOnDemandStartTimeout": "10s",
      "sourceOnDemandCloseAfter": "10s",
      "sourceRedirect": "",
      "disablePublisherOverride": false,
      "fallback": "",
      "publishUser": "",
      "publishPass": "",
      "publishIPs": [],
      "readUser": "",
      "readPass": "",
      "readIPs": [],
      "runOnInit": "",
      "runOnInitRestart": false,
      "runOnDemand": "",
      "runOnDemandRestart": false,
      "runOnDemandStartTimeout": "10s",
      "runOnDemandCloseAfter": "10s",
      "runOnPublish": "",
      "runOnPublishRestart": false,
      "runOnRead": "",
      "runOnReadRestart": false
    }
  }
}
```

### Check the FreeTAKHub Server (or Node-RED Server)

Open a web browser to:

```
http://<YOUR_IP_ADDRESS>:1880/
```

Confirm you see a login prompt.

# Install on DigitalOcean with Terraform

This installation has only been tested on Ubuntu 20.04.

Other operating systems may work, but are untested.

## Step 1. Create admin user

The later executions will require admin privileges.

Create an adminuser first:

```console
sudo adduser adminuser
```

Add passwordless to adminuser.

First type:

```console
sudo visudo
```

Then add at the bottom:

```console
adminuser ALL=(ALL) NOPASSWD: ALL
```

To save and quit in the `nano` editor:

1. Press `CTRL + O` then `ENTER` to save.
1. Then press `CTRL + X` to exit.

## Step 2. Download Terraform and Ansible

In the Ubuntu console:

```console
sudo apt update
```

```console
sudo apt install -y software-properties-common gnupg curl git
```

```console
sudo add-apt-repository -y --update ppa:ansible/ansible
```

```console
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
```

```console
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
```

```console
sudo apt install -y ansible terraform
```

## Step 3. Clone the `FreeTAKHub-Installation` Git repository

Go to the home directory:

```console
cd ~
```

```console
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
```

Go to the `FreeTAKTeam/FreeTAKHub-Installation` directory:

```console
cd FreeTAKTeam/FreeTAKHub-Installation
```

## Step 4. Generate a public/private key pair

For the default, enter (and keep pressing enter):

```console
ssh-keygen
```

Print out the public key for the next step.

If you did the default, the command will be:

```console
cat ~/.ssh/id_rsa.pub
```

## Step 5. Add your public key to your Digital Ocean project

See: <https://docs.digitalocean.com/products/droplets/how-to/add-ssh-keys/to-account/>

## Step 6. Generate a Digital Ocean Personal Access Token

See: <https://docs.digitalocean.com/reference/api/create-personal-access-token/>

## Step 7. Execute

In the top-level directory of the project, initialize Terraform:

```console
terraform init
```

Then apply:

```console
terraform apply
```

You will then be prompted for your DigitalOcean Token and private key path:

```console
var.digitalocean_token
  Enter a value: <DIGITALOCEAN_TOKEN_HERE>

var.private_key_path
  ABSOLUTE path to private key, for example: /home/adminuser/.ssh/id_rsa

  Enter a value: /home/adminuser/.ssh/id_rsa
```
