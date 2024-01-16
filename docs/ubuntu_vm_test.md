
# Testing FTS Zero Touch Installer on Ubuntu 

Obviously, the ZTI can be tested in a clean native Ubuntu environment.
However, setting up such an environment can consume time.
So, while running FTS on dedicated hardware is the correct choice 
in a production environment it is more appropriate to test with a virtual machine.

## Setting up the Virtual Machine

Thankfully, Canonical has provided tooling to make setting up an Ubuntu VM easy.

[Multipass Tutorials](https://multipass.run/docs/tutorials)

* [Multipass Windows](https://multipass.run/docs/windows-tutorial)
* [Multipass Linux](https://multipass.run/docs/get-started-with-multipass-linux)
* [Multipass MacOS](https://multipass.run/docs/mac-tutorial)

Any of these are suitable for testing.

We will want to specify a specific Ubuntu version.
```shell
multipass find
```
Of the choices available we want `v22.04`.
```shell
multipass launch 22.04 --name fts-test --memory 4G --disk 10G --cpus 2
```
We can verify the image.
```shell
multipass exec fts-test -- lsb_release -a
multipass info fts-test
```

## Installing Using ZTI

note: The following steps may be modified to accommodate your situation.

When testing a change the working copy will be 
[mounted to the running instance](https://multipass.run/docs/share-data-with-an-instance).

### Mount the Working Repository

Make a mount point on the virtual machine.
```bash
multipass exec fts-test -- mkdir fts-zti
```
Mount the directory containing the working repository.
Note: On Windows you will need
to [enable privileged mounts](https://multipass.run/docs/privileged-mounts).
```shell
# multipass set local.privileged-mounts=true
multipass mount $HOME/fts-installer fts-test:/home/ubuntu/fts-zti
````

### Run the ZTI

Start the prepared virtual machine.
```shell
multipass shell fts-test
```
Install FTS using the candidate ZTI.
```bash
cat /home/ubuntu/fts-zti/scripts/easy_install.sh | sudo bash -s -- --verbose --repo file:///home/ubuntu/fts-zti/.git
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

