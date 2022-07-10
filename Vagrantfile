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

  config.vm.synced_folder ".", "/vagrant", disabled: true

  $script = <<-SCRIPT
  echo Updating APT Packages...
  sudo apt update -y && sudo apt upgrade -y
  SCRIPT

  config.vm.provision "shell", inline: $script

end
