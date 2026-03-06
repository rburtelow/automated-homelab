# Integration with Proxmox Terraform

This directory contains Talos configuration that works alongside the `talos-cluster-proxmox` directory.

## Option 1: Using Terraform Remote State (Recommended)

If your proxmox resources are in a separate terraform state, use `terraform_remote_state`:

1. Create `data_proxmox.tf`:

```hcl
data "terraform_remote_state" "proxmox" {
  backend = "local"  # or "s3", "gcs", etc. - match your proxmox backend
  config = {
    path = "../talos-cluster-proxmox/terraform.tfstate"
  }
}
```

2. Update `config.auto.tfvars`:

```hcl
controlplane_ips = data.terraform_remote_state.proxmox.outputs.proxmox_ip_addresses_talos_cp
worker_ips = data.terraform_remote_state.proxmox.outputs.proxmox_ip_addresses_talos_worker
```

## Option 2: Manual IP Configuration

If you prefer to manage IPs manually, update `config.auto.tfvars`:

```hcl
controlplane_ips = {
  "01" = "192.168.100.92"
  "02" = "192.168.100.61"
  "03" = "192.168.100.XXX"  # Add when third CP is ready
}

worker_ips = {
  "03" = "192.168.100.8"
  "04" = "192.168.100.239"
  # Add more as workers are created
}
```

## Option 3: Same Terraform Workspace

If both proxmox and talos configs are in the same terraform workspace, you can reference the outputs:

```hcl
controlplane_ips = {
  for k, v in proxmox_vm_qemu.talos_cp : k => v.default_ipv4_address
}
worker_ips = {
  for k, v in proxmox_vm_qemu.talos_worker : k => v.default_ipv4_address
}
```

Or if you have outputs defined in the proxmox module:

```hcl
controlplane_ips = proxmox_ip_addresses_talos_cp
worker_ips = proxmox_ip_addresses_talos_worker
```

Note: The keys in the maps must match the node numbers from proxmox (control planes: "01", "02", "03"; workers: "03"-"09").

