# PROVIDER INFORMATION
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
    }
  }
}

provider "digitalocean" {
  token = var.digitalocean_token
}

# MAIN SERVER DROPLET
resource "digitalocean_droplet" "mainserver" {
  name     = "mainserver"
  image    = "ubuntu-20-04-x64"
  size     = "s-2vcpu-2gb"
  region   = "nyc3"
  ssh_keys = data.digitalocean_ssh_keys.keys.ssh_keys.*.id
  tags     = ["droplet", "mainserver", ]

  provisioner "remote-exec" {

    connection {
      host        = digitalocean_droplet.mainserver.ipv4_address
      user        = "root"
      type        = "ssh"
      private_key = file("${var.private_key_path}")
      timeout     = 1800
    }

    inline = [
      "sudo apt -qqq update",
      "sudo apt -qqqqy install python3",
    ]

  }

  provisioner "local-exec" {
    command = join(" ", [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ansible-playbook",
      "-u root -i '${self.ipv4_address},'",
      "-e \"fts_ipv4=${self.ipv4_address}\"",
      "-e \"webmap_ipv4=${self.ipv4_address}\"",
      "install_mainserver.yml"
    ])
  }

}

# NODE-RED SERVER DROPLET
resource "digitalocean_droplet" "noderedserver" {
  name     = "noderedserver"
  image    = "ubuntu-20-04-x64"
  size     = "s-1vcpu-1gb"
  region   = "nyc3"
  ssh_keys = data.digitalocean_ssh_keys.keys.ssh_keys.*.id
  tags     = ["droplet", "noderedserver", ]

  provisioner "remote-exec" {

    connection {
      host        = self.ipv4_address
      user        = "root"
      type        = "ssh"
      private_key = file("${var.private_key_path}")
      timeout     = 1800
    }

    inline = [
      "sudo apt -qqq update",
      "sudo apt -qqqqy install python3",
    ]

  }

  provisioner "local-exec" {
    command = join(" ", [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ansible-playbook",
      "-u root -i '${self.ipv4_address},'",
      "-e \"fts_ipv4=${digitalocean_droplet.mainserver.ipv4_address}\"",
      "-e \"videoserver_ipv4=${digitalocean_droplet.videoserver.ipv4_address}\"",
      "-e \"nodered_wait_for_videoserver=true",        # Node-RED Server will wait for Video Server
      "-e \"nodered_wait_for_videoserver_timeout=600", # Max seconds Node-RED Server will wait
      "install_noderedserver.yml"
    ])
  }
}

# VIDEO SERVER DROPLET
resource "digitalocean_droplet" "videoserver" {
  name     = "videoserver"
  image    = "ubuntu-20-04-x64"
  size     = "s-1vcpu-1gb"
  region   = "nyc3"
  ssh_keys = data.digitalocean_ssh_keys.keys.ssh_keys.*.id
  tags     = ["droplet", "videoserver", ]

  provisioner "remote-exec" {

    connection {
      host        = self.ipv4_address
      user        = "root"
      type        = "ssh"
      private_key = file("${var.private_key_path}")
      timeout     = 1800
    }

    inline = [
      "sudo apt -qqq update",
      "sudo apt -qqqqy install python3",
    ]

  }

  provisioner "local-exec" {
    command = join(" ", [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ansible-playbook",
      "-u root -i '${self.ipv4_address},'",
      "-e \"videoserver_ipv4=${self.ipv4_address}\"",
      "install_videoserver.yml"
    ])
  }

}

# KEYS/TOKENS
data "digitalocean_ssh_keys" "keys" {}
variable "digitalocean_token" {}
variable "private_key_path" {
  description = "Absolute path to private key. For example: /home/user/.ssh/id_rsa"
  type        = string
}

# OUTPUTS AT THE END OF EXECUTION
output "Main_Server_IPv4" {
  value = digitalocean_droplet.mainserver.ipv4_address
}

output "Video_Server_IPv4" {
  value = digitalocean_droplet.videoserver.ipv4_address
}

output "Node-RED_Server_IPv4" {
  value = digitalocean_droplet.noderedserver.ipv4_address
}

output "Main_Server_SSH_command" {
  value = "ssh -i ${var.private_key_path} -t root@${digitalocean_droplet.mainserver.ipv4_address} 'cd /root;bash'"
}

output "Video_Server_SSH_Command" {
  value = "ssh -i ${var.private_key_path} -t root@${digitalocean_droplet.videoserver.ipv4_address} 'cd /root;bash'"
}

output "Node-RED_Server_SSH_Command" {
  value = "ssh -i ${var.private_key_path} -t root@${digitalocean_droplet.noderedserver.ipv4_address} 'cd /root;bash'"
}

output "Node-RED_Server_URL" {
  value = "http://${digitalocean_droplet.noderedserver.ipv4_address}:1880/"
}

output "Video_Server_URL" {
  value = "http://${digitalocean_droplet.videoserver.ipv4_address}:9997/v1/config/get"
}

output "Main_Server_WebMap_URL" {
  value = "http://${digitalocean_droplet.mainserver.ipv4_address}:8000/"
}

output "Main_Server_User_Interface_Credentials" {
  value = "username: admin     password: password"
}

output "Main_Server_User_Interface_URL" {
  value = "http://${digitalocean_droplet.mainserver.ipv4_address}:5000/"
}
