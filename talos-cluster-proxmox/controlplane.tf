resource "proxmox_vm_qemu" "talos_cp" {
  for_each = toset(["01", "02", "03"])

  vmid        = 200 + tonumber(each.value)
  target_node = var.pm_host
  name        = "talos-cp-${each.value}"
  memory      = 8196
  vm_state    = "running"
  os_type     = "ubuntu"
  scsihw      = "virtio-scsi-pci"
  agent       = 1
  agent_timeout = 10

  cpu {
    cores   = 4
    sockets = 1
  }

  network {
    id        = 1
    bridge    = "vmbr0"
    firewall  = false
    link_down = false
    model     = "virtio"
  }

  disks {
    ide {
      ide2 {
        cdrom {
          iso = "local:iso/metal-amd64.iso"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          discard    = true
          emulatessd = true
          size       = "20G"
          storage    = "local-lvm"
        }
      }
    }
  }
}

output "proxmox_ip_addresses_talos_cp" {
  value = {
    for k, v in proxmox_vm_qemu.talos_cp : k => v.default_ipv4_address
  }
}
