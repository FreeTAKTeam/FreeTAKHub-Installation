
# Testing FTS Zero Touch Installer on Raspberry Pi with Ubuntu 

On the Raspberry Pi the ZTI can is tested in a clean native Ubuntu environment.

## Preparing the Raspberry Pi with Ubuntu

The official installation instructions for `RaspPi` are
[available in the user guide](https://freetakteem.github.io/FreeTAKServer-User-Docs/Installation/RaspberryPi/Installation/).
Those instructions will not be duplicated here.

Use those official instructions to prepare the SD card.
As mentioned in the official instructions you will need the IP address of the RaspPi.

```bash
ip addr show
````

#### Install FTS Using `ZTI`

This example uses a Commited Branch from a Github Repository.
Some care should be taken when running the following command 
to get the `easy_install.sh` from the same repository and branch as the ZTI.

```bash
wget -qO - https://raw.githubusercontent.com/FreeTAKTeam/FreeTAKHub-Installation/main/scripts/easy_install.sh | sudo bash -s -- --verbose --repo https://github.com/FreeTAKTeam/FreeTAKHub-Installation.git --branch main --ip-addr 127.0.0.1 
```

As an example here are the setting I used to test a change to the `ZTI`.
```bash
wget -qO - https://raw.githubusercontent.com/babeloff/FreeTAKHub-Installation/main/scripts/easy_install.sh | sudo bash -s -- --verbose --repo https://github.com/babeloff/FreeTAKHub-Installation.git --branch main --ip-addr 10.2.118.115 
```


## Configuration of FTS

The official configuration instructions are
[available in the user guide](https://freetakteam.github.io/FreeTAKServer-User-Docs/Installation/Operation/).
Those instructions will not be duplicated here.

## Running Installation Tests (smoke test)

[Smoke testing](https://en.wikipedia.org/wiki/Smoke_testing_(software))
is performed with the installation validation instructions.
The official installation validation instructions are
[available in the user guide](https://freetakteam.github.io/FreeTAKServer-User-Docs/Installation/Troubleshooting/InstallationCheck/).
Those instructions will not be duplicated here.
