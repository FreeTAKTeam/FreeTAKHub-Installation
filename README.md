![CI](https://github.com/FreeTAKTeam/FreeTAKHub-Installation/actions/workflows/zerotouch.yml/badge.svg)

This page is for developers of the Zero Touch Installer for [FreeTAKServer](https://github.com/FreeTAKTeam/FreeTakServer).
Please refer to the [official documentation ](https://freetakteam.github.io/FreeTAKServer-User-Docs/) for usage.

# Configuring the Development Environment

## Cloning the Repository

Clone the origin repository.
The following is the official repository.
```bash
git clone --origin upstream https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git ${HOME}/fth-install
```

You will want to commit your work into a fork of the repository.
```bash
pushd  ${HOME}/fth-install
git remote add origin <url-of-fork>
```

# Running the ZTI locally

You will need some variant of Ubuntu 22.04 on your development machine.
The following will install FTS on your development machine.
```bash
cat ./scripts/easy_install.sh | sudo bash -s -- --verbose
```

This will install the production repository,
unless you are modifying `scripts/easy_install.sh` you will want your cloned repository.

The following will remove any previously retrieved repository replacing it with a clone of the provided one.
```bash
pushd  ${HOME}/fth-install
cat ./scripts/easy_install.sh | sudo bash -s -- --verbose --repo file://$(pwd)/.git
```

So long as you are working with the same git repository the `--repo` option could (and should)
be omitted from subsequent runs as the default is to reuse the clone.


## Regression Testing the ZTI

The ZTI is officially supported on the following platforms:

* Raspberry Pi
* [Ubuntu Server](docs/ubuntu_vm_test.md)
* Digital Ocean Cloud




