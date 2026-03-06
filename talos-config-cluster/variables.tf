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

