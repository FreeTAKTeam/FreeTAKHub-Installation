
# Testing FTS Zero Touch Installer on Raspberry Pi with Ubuntu 

On the Raspberry Pi the ZTI can is tested in a clean native Ubuntu environment.

## Preparing the Raspberry Pi with Ubuntu

The official installation instructions for `RaspPi` are
[available in the user guide](https://freetakteem.github.io/FreeTAKServer-User-Docs/Installation/RaspberryPi/Installation/).
Those instructions will not be duplicated here.

Use those official instructions to prepare the SD card.
As mentioned in the official instructions you will need an IP address for the RaspPi.
It is likely that your RaspPi was asigned an IP address by a DHCP server.
```bash
ip addr show
ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```
Alternatively, you may be on the public internet.
```bash
curl ifconfig.me/ip
```

#### Install FTS Using `ZTI`

This example uses a Committed Branch from a `Github` Repository.
Some care should be taken when running the following command 
to get the `easy_install.sh` from the same repository and branch as the ZTI.

The official GitHub is `FreeTAKTeam`,
if you are working in a fork you will need to use that.

```bash
export MY_IPA=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
export MY_GITHUB=babeloff
export MY_BRANCH=issue_120
echo "github: ${MY_GITHUB}, branch: ${MY_BRANCH}, addr: ${MY_IPA}"
```

The environment variables default values:
```bash
export MY_IPA=127.0.0.1
export MY_GITHUB=FreeTAKTeam
export MY_BRANCH=main
```

```bash
wget -qO - https://raw.githubusercontent.com/${MY_GITHUB:-FreeTAKTeam}/FreeTAKHub-Installation/${MY_BRANCH:-main}/scripts/easy_install.sh | \
    sudo bash -s -- \
      --verbose \
      --repo https://github.com/${MY_GITHUB:-FreeTAKTeam}/FreeTAKHub-Installation.git \
      --branch ${MY_BRANCH:-main} \
      --ip-addr ${MY_IPA:-127.0.0.1}
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
