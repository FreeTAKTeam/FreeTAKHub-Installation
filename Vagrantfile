# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = ENV["IMAGE_DISTRO"]
  config.vm.hostname = ENV["VAGRANTBOX"]
  config.vm.boot_timeout = 1800 #30 minutes
  config.vm.provider :virtualbox do |v|
    v.memory = 4096
    v.cpus = 2
    end
  config.vm.provider :linode do |provider, override|
    override.ssh.private_key_path =  ENV["SSH_KEY"]
    #override.vm.box = 'linode/ubuntu2004'
    #override.vm.box = 'bento/ubuntu-20.04'
    provider.api_key = ENV["LIN_API_KEY"]
    provider.distribution = 'Ubuntu 20.04 LTS'
    provider.datacenter = 'newark'
    provider.plan = 'Linode 8GB' # This will work
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
  config.vm.provider :digital_ocean do |provider, override|
    override.ssh.private_key_path = ENV["SSH_KEY"]
    provider.ssh_key_name = ENV["DO_SSH_KEY_NAME"]
    #override.vm.box = 'digital_ocean'
    #override.vm.box_url = "https://github.com/devopsgroup-io/vagrant-digitalocean/raw/master/box/digital_ocean.box"
    override.nfs.functional = false
    override.vm.allowed_synced_folder_types = :rsync
    provider.token = ENV["DO_API_KEY"]
    provider.image = 'ubuntu-20-04-x64'
    provider.region = 'nyc1'
    provider.size = 's-4vcpu-8gb'
    provider.backups_enabled = false
    provider.private_networking = false
    provider.ipv6 = false
    provider.monitoring = false
    end
  end
end
