# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = ENV["IMAGE_DISTRO"]
  config.vm.hostname = ENV["VAGRANTBOX"] + ".box"

  config.vm.provider :virtualbox do |v|
    v.memory = 4096
    v.cpus = 2
  end

  config.vm.synced_folder ".", "/vagrant", disabled: true

end
