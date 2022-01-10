# FreeTAKHub Installation

FreeTAKHub installation is a set of Ansible scripts that allow you to:
- create the target nodes
- install FTS and all the additional modules
- configure FTS

## Control Machine

To use this module you need to install Ansible on your control machine that will control all the installations of FTS.

### Install Ansible with pip

```console
pip install ansible
```

### Install Ansible control nodes with OS packages

In Ubuntu console:

```console
sudo apt update
sudo apt install -y software-properties-common
sudo sudo apt-add-repository –y -u ppa:ansible/ansible

sudo apt install ansible
```

### Install

An example default install playbook is defined in: `freetakhub_install.yml`.

This playbook installs all FreeTAKServer and components to your machine.

To execute the default install playbook, enter:

```console
sudo ansible-playbook freetakhub_install.yml
```
### Uninstall

An example default uninstall playbook is defined in: `freetakhub_uninstall.yml`.

The playbook uninstalls all FreeTAKServer and components on your machine.

To execute the default uninstall playbook, enter:

```console
sudo ansible-playbook freetakhub_uninstall.yml
```
