Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/focal64"
    config.vm.hostname = "fts.box"
    config.vm.provision :shell, privileged: true,
      inline: <<-EOS
        wget -qO - bit.ly/ftszerotouch | sudo bash
      EOS

    config.vm.provider "virtualbox" do |v|
      v.memory = 4096
      v.cpus = 2
    end
  end
