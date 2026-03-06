resource "proxmox_vm_qemu" "talos_worker" {
  for_each = toset(["03", "04", "05", "06", "07", "08", "09"])

  vmid        = 201 + tonumber(each.value)
  target_node = var.pm_host
  name        = "talos-worker-${each.value}"
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
          size       = "100G"
          storage    = "local-lvm"
        }
      }
    }
  }
}

output "proxmox_ip_addresses_talos_worker" {
  value = {
    for k, v in proxmox_vm_qemu.talos_worker : k => v.default_ipv4_address
  }
}
