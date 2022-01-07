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
sudo apt install software-properties-common
sudo apt-add-repository –yes –update ppa:ansible/ansible
sudo apt install ansible
```

### Execute playbook

In console in project root

```
sudo ansible-playbook -i hosts.ini main.yml
```
