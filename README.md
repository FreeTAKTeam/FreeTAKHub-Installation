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

### Example Playbooks

An example playbook is located in: `playbooks/install.yml`.

An example hosts file is located in: `hosts/localhost.yml`.

The playbooks or hosts files may need editing to cover your specific machine.

An example run command: From the root directory of the project, type:

```configure
sudo ansible-playbook -i hosts/localhost.yml playbooks/install.yml
```
