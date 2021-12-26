# FreeTAKHub Installation
FreeTAKHub installation is a set of Ansible scripts that allow you to:
- Create the target Nodes
- Install FTS and all the additional modules
- configure FTS

## Control Machine
to use this module you need to install Ansible on your control Machine that will controll all the installations of FTS

### Install Ansible with Pip

```
$ pip install ansible
```

### Install Ansible Control Nodes With OS Packages
In Ubuntu console

```
$ sudo apt update
$ sudo apt install software-properties-common
$ sudo apt-add-repository –yes –update ppa:ansible/ansible
$ sudo apt install ansible
```

### Execute playbook
In console in project root

```
$ sudo ansible-playbook -i hosts.ini main.yml
```
