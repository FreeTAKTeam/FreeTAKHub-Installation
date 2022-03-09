# FreeTAKHub Installation

Currently, FreeTAKHub has 5 components:

1. FreeTAKServer (FTS)
2. FreeTAKServer-UI
3. WebMap Server
4. Video Server (RTSP Server)
5. Node-RED Server

The installation is a set of Ansible/Terraform scripts that allow you to:

- Create the target nodes.
- Install FTS and all the additional modules.
- Configure FTS.

Currently FreeTAKServer and components have been tested successfully on Ubuntu 20.04.

Other Linux distributions may work, but they have not been tested.

## Windows Prerequisites

This is required only if you want to use Windows.

You must be running Windows 10 version 2004 and higher (Build 19041 and higher) or Windows 11.

To install on Windows, you will have to:

1. Install WSL2.

    See: <https://docs.microsoft.com/en-us/windows/wsl/install>

    See also: <https://www.omgubuntu.co.uk/how-to-install-wsl2-on-windows-10>

    See also: <https://www.sitepoint.com/wsl2/>

1. Install the WSL Ubuntu 20.04 distribution.

    See: <https://www.microsoft.com/en-us/p/ubuntu-2004-lts/9n6svws3rx71>


# Zero Touch Deployment

```console
wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/scripts/easy_install.sh | bash
```

This approach assumes that you have a empty Ubuntu 20.04.

The script will install and configure all FreeTAKHub components.

* FTS: hosts the core of FTS
* FTS Web UI: uses the API service 1935 to interacts with FTS
* FTH webMap :  this connects to FTS using the TCP COT service and port 8087
* Video Service: streams video. 
* FTH server: runs other integrations such as the Video Service Checker and SALUTE report. The video Service checker has a strategy to verify if streams are running there and notifies FTS.
![image](https://user-images.githubusercontent.com/60719165/149667427-c65877ef-56dc-4a5d-a32a-e2693de7fda5.png)

# Advanced Install (Options)
this installation will give you the ability to select which components you need
```console
wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/scripts/advanced_install.sh | bash
```

shorter url (under construction)
```console
wget -qO rb.gy/ocghax | bash
```


# Install FreeTAKHub to your machine with Ansible

## Step 1. Clone the FreeTAKHub-Installation Git repository

In the console:

```console
sudo apt update
```

Make sure you have Git installed:

```console
sudo apt install -y git
```

Go to your home directory:

```console
cd ~
```

Clone the repo:

```console
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
```

Go to the top-level directory of the repository:

```console
cd FreeTAKHub-Installation
```

In case you already previously created the repository, pull the latest:

```console
git pull
```

## Step 2. Install Ansible

### Automated Ansible Installation

In the top-level directory, enter:

```console
./scripts/init.sh
```

Optional: To activate the virtual environment, enter:

```console
activate
```

To deactivate:

```console
deactivate
```

To know more about Python virtual environments and why they are a good idea, see:

<https://realpython.com/python-virtual-environments-a-primer/>

### Manual Installation for Ansible
if you prefer to have more control use this method.

In the console:

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

This script install FreeTAKServer and all of its components to your machine:

```console
./scripts/install.sh
```

## Checking Your Installation

### Check FTS core

open a browser to:

```console
http://[YOURIP]::5000/
```

- login with admin / password
- change your password immediately
- check if the services are on OK (blue)
![image](https://user-images.githubusercontent.com/60719165/148986287-0c83aa3f-e909-4b38-bc81-d66cddb08f89.png)
- connect a client to the server
- click on the Webmap tab
- you should see the client connected in the webmap

#### Check video server

Open a browser to:

http://[YOURIP]:9997/v1/config/get

you will see a configuration in Json format like this:

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
  "apiAddress": "[YOURIP]:9997",
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

### Node-RED

Open a browser to

```console
http://[YOURIP]::8081/
```

# Install on DigitalOcean with Terraform and Ansible

This installation method has been tested with Ubuntu 20.04.

Other Linux distributions may work, but they have not been tested.

## Step 1. Clone the FreeTAKHub-Installation Git repository

In the console:

```console
sudo apt update
```

Make sure you have Git installed:

```console
sudo apt install -y git
```

Go to your home directory:

```console
cd ~
```

Clone the repo with:

```console
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
```

Go to the top-level directory

```console
cd FreeTAKHub-Installation
```

In case you already previously created the repository, pull the latest:

```console
git pull
```

## Step 2. Install Terraform and Ansible

In the top-level directory of the repository:

```console
./scripts/init.sh
```

```console
./scripts/install.sh
```

Optional: To activate the virtual environment, enter:

```console
activate
```

To deactivate:

```console
deactivate
```

To know more about Python virtual environments and why they are a good idea, see:

<https://realpython.com/python-virtual-environments-a-primer/>


## Step 3. Add your public key to your Digital Ocean project

See: <https://docs.digitalocean.com/products/droplets/how-to/add-ssh-keys/to-account/>

## Step 4. Generate a Digital Ocean Personal Access Token

See: <https://docs.digitalocean.com/reference/api/create-personal-access-token/>

## Step 5. Install FreeTAKServer and Components onto DigitalOcean

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
  ABSOLUTE path to private key, for example: /home/user/.ssh/id_rsa

  Enter a value: /home/user/.ssh/id_rsa
```

To destroy your droplets:

```console
terraform destroy
```
