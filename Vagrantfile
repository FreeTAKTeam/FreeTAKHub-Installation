# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = ENV["IMAGE_DISTRO"] || "ubuntu/jammy64"
  config.vm.hostname = ENV["VAGRANTBOX"] || "default-hostname"
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.boot_timeout = 1800 #30 minutes
  config.vm.provider :virtualbox do |vb, override|
    vb.memory = 4096
    vb.cpus = 2
    end
  config.vm.provider :linode do |linode, override|
    override.ssh.private_key_path =  ENV["SSH_KEY"]
    #override.vm.box = 'linode/ubuntu2004'
    #override.vm.box = 'bento/ubuntu-20.04'
    linode.api_key = ENV["LIN_API_KEY"]
    linode.distribution = 'Ubuntu 20.04 LTS'
    linode.datacenter = 'newark'
    linode.plan = 'Linode 8GB' # This will work
    # provider.plan = 'Linode 2048' # This will still work
    # provider.plan = 'Linode 2' # This may work, but may be ambiguous
    # provider.planid = <int>
    # provider.paymentterm = <*1*,12,24>
    # provider.datacenterid = <int>
    # provider.image = <string>
    # provider.imageid = <int>
    # provider.kernel = <string>
    # provider.kernelid = <int>
    # provider.private_networking = <boolean>
    # provider.stackscript = <string> # Not Supported Yet
    # provider.stackscriptid = <int> # Not Supported Yet
    # provider.distributionid = <int>
    end
  config.vm.provider :digital_ocean do |digitalocean, override|
    override.ssh.private_key_path = ENV["SSH_KEY"]
    digitalocean.ssh_key_name = ENV["DO_SSH_KEY_NAME"]
    #override.vm.box = 'digital_ocean'
    #override.vm.box_url = "https://github.com/devopsgroup-io/vagrant-digitalocean/raw/master/box/digital_ocean.box"
    #override.nfs.functional = false
    #override.vm.allowed_synced_folder_types = :rsync
    digitalocean.token = ENV["DO_API_KEY"]
    digitalocean.image = 'ubuntu-20-04-x64'
    digitalocean.region = 'nyc1'
    digitalocean.size = 's-4vcpu-8gb'
    digitalocean.backups_enabled = false
    digitalocean.private_networking = false
    digitalocean.ipv6 = false
    digitalocean.monitoring = false
    end
  end
