# FreeTAKHub Installation

FreeTAKHub installation is a set of Ansible/Terraform scripts that allow you to:

- create the target nodes
- install FTS and all the additional modules
- configure FTS

# Windows Prerequisites

Currently FreeTAKServer and components have been tested successfully on Ubuntu 20.04.

Other Linux distributions may work, but they have not been tested.

To install on Windows, you will have to:

1. Install WSL2.

    See: <https://docs.microsoft.com/en-us/windows/wsl/install>

    See also: <https://www.omgubuntu.co.uk/how-to-install-wsl2-on-windows-10>

    See also: <https://www.sitepoint.com/wsl2/>

1. Install the WSL Ubuntu 20.04 distribution.

    See: <https://www.microsoft.com/en-us/p/ubuntu-2004-lts/9n6svws3rx71>

# Install with Ansible

## Step 1. Install Ansible and package dependencies

In the Ubuntu console:

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
sudo apt install -y ansible git
```

See: <https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-ubuntu>

## Step 2. Clone the FreeTAKHub-Installation Git repository

```console
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
```

In case you already created the repository previously, pull the latest:

```console
cd FreeTAKTeam/FreeTAKHub-Installation

```console
git pull  https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
```

## Step 3. Install with Ansible

An example default install playbook is defined in: `install_all.yml`.

This playbook installs all FreeTAKServer and components to your machine.

To execute the default install playbook, go into FreeTAKHub-Installation

```console
cd FreeTAKTeam/FreeTAKHub-Installation
```

```console
sudo ansible-playbook install_all.yml
```

# Install on DigitalOcean with Terraform and Ansible

This installation method has been tested with Ubuntu 20.04.

Other Linux distributions may work, but they have not been tested.

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

## Step 3. Clone the FreeTAKHub-Installation Git repository

Go to your home directory:

```console
cd ~
```

```console
git clone https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git
```

Go into the directory:

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
  ABSOLUTE path to private key, for example: /home/admin/.ssh/id_rsa

  Enter a value: /home/admin/.ssh/id_rsa
```
