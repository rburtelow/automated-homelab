variable "cluster_name" {
    type = string
}

variable "talos_version" {
    type = string
}

variable "talos_vip" {
    type = string
}

variable "talos_network_gateway" { 
    type = string
}

variable "talos_install_image" {
    type = string
}


variable "controlplane_ips" {
  type = map(string)
  description = "Map of control plane IP addresses, keyed by node number (e.g., { \"01\" = \"192.168.100.92\", \"02\" = \"192.168.100.61\" })"
}

variable "worker_ips" {
  type = map(string)
  description = "Map of worker IP addresses, keyed by node number (e.g., { \"03\" = \"192.168.100.8\", \"04\" = \"192.168.100.239\" })"
}

variable "worker_extra_disk_keys" {
  type        = list(string)
  default     = []
  description = "Worker node keys (matching worker_ips) that have an extra non-system virtio disk to provision as a Longhorn disk mounted at /var/lib/longhorn/extra"
}

