terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.46.0"
    }
  }
  required_version = ">= 1.6.0"
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true
}

resource "proxmox_virtual_environment_vm" "k3s_control_plane" {
  name      = "k3s-cp-01"
  node_name = "g4"
  vm_id     = 300

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 3072
  }

  disk {
    datastore_id = "local-lvm"
    size         = 32
    interface    = "scsi0"
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.30/24"
        gateway = "192.168.1.254"
      }
    }
    dns {
      servers = ["192.168.1.21"]
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
  }

  clone {
    vm_id = var.template_vm_id
  }

  agent {
    enabled = true
  }

  tags = ["k3s", "control-plane"]
}

resource "proxmox_virtual_environment_vm" "k3s_workers" {
  for_each = {
    "k3s-w-01" = { vm_id = 301, ip = "192.168.1.31" }
    "k3s-w-02" = { vm_id = 302, ip = "192.168.1.32" }
  }

  name      = each.key
  node_name = "g4"
  vm_id     = each.value.vm_id

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    size         = 40
    interface    = "scsi0"
    file_format  = "raw"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = "192.168.1.254"
      }
    }
    dns {
      servers = ["192.168.1.21"]
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
  }

  clone {
    vm_id = var.template_vm_id
  }

  agent {
    enabled = true
  }

  tags = ["k3s", "worker"]
}
