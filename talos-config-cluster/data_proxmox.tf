# Reference proxmox outputs using terraform_remote_state
# Uncomment the data source and locals blocks below to use proxmox remote state
#
# data "terraform_remote_state" "proxmox" {
#   backend = "local"  # or "s3", "gcs", etc. - match your proxmox backend
#   config = {
#     path = "../talos-cluster-proxmox/terraform.tfstate"
#   }
# }
# locals {
#   controlplane_ips = try(data.terraform_remote_state.proxmox.outputs.proxmox_ip_addresses_talos_cp, var.controlplane_ips)
#   worker_ips = try(data.terraform_remote_state.proxmox.outputs.proxmox_ip_addresses_talos_worker, var.worker_ips)
# }

# Using manual IP configuration via variables instead of Proxmox auto-detection


