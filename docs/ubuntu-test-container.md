# Testing FTS Zero Touch Installer on Ubuntu 

Obviously, the ZTI can be tested in a clean native Ubuntu environment.
However, setting up such an environment can consume time.
So, while in a production environment, running FTS on dedicated hardware is the correct choice,
in a test environment it is more appropriate to use a container.

## Setting up the container

The test container can be constructed with any number of technologies.

[Distrobox](https://wiki.archlinux.org/title/Distrobox)
[Ptyrix](https://flathub.org/apps/app.devsuite.Ptyxis)
[Boxbuddy](https://flathub.org/apps/io.github.dvlv.boxbuddyrs)

We will want to specify a specific Ubuntu version we want `v22.04`.
```shell
distrobox create --image ubuntu:22.04 --name fts-test-install --yes \
  --init --additional-packages "systemd libpam-systemd pipewire-audio-client-libraries" 
```

Enter the container
```shell
distrobox enter --name fts-test-install
```

## Use Zero Touch Intallation (ZTI)

Note: The following steps may be modified to accommodate your situation.

### The Working Repository

The project working directory is mounted into the distrobox.
The following is an example:
```bash
cd ./Projects/fts-install
export MY_WD=$(pwd)
```

Your test will probably need the locally known IP address.
You may change the configured IP address later,
but it is easiest to handle it now.
It is likely you will want the host interface the example here instead uses `docker0`.
```bash
export MY_IPA=$(ip -4 addr show docker0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
```

You opened a branch for your issue.
```bash
export MY_BRANCH=issue_118
```

```bash
echo "My IPA: ${MY_IPA}, WD: ${MY_WD}, ISSUE: ${MY_BRANCH}"
```

Install FTS using the candidate ZTI.
The `--verbose` is optional.

#### Use a Committed Branch from a Git Repository
Notice that in the following command the `easy_install.sh` is taken from
a working tree, while the branch is from the committed repository.

```bash
sudo bash ${MY_WD}/scripts/easy_install.sh -- \
   --verbose --repo file://${MY_WD}/.git \
   --branch ${MY_BRANCH:-main} \
   --ip-addr ${MY_IPA} 
```
If you want to use Python packages from the https://test.pypi.org repository.
```bash
cat ${MY_WD}/scripts/easy_install.sh | \
   sudo bash -s -- --verbose \
      --repo file://${MY_WD}/.git \
      --branch ${MY_BRANCH:-main} \
      --ip-addr ${MY_IPA} \
      --pypi https://test.pypi.org
```

### Configuration

The official configuration instructions are
[available in the user guide](https://freetakteam.github.io/FreeTAKServer-User-Docs/Installation/Operation/).
Those instructions will not be duplicated here.

## Running Installation Tests (smoke test)

[Smoke testing](https://en.wikipedia.org/wiki/Smoke_testing_(software))
is performed with the installation validation instructions.
The official installation validation instructions are
[available in the user guide](https://freetakteam.github.io/FreeTAKServer-User-Docs/Installation/Troubleshooting/InstallationCheck/).
Those instructions will not be duplicated here.

## Resetting the `distrobox`

### Hard Reset
The distrobox can be deleted and recreated.

```shell
distrobox rm fts
```

### Soft Reset

The soft reset creates a new distrobox from a previous box.
(You did make a snapshot, right?)
```shell
distrobox create --clone fts --name fts-test
```