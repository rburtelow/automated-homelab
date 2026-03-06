resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.talos_vip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  #kubernetes_version = var.kubernetes_version
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.talos_vip}:6443"
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  #kubernetes_version = var.kubernetes_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.talos_vip]
}

# First control plane (01) - no bootstrap dependency
resource "talos_machine_configuration_apply" "controlplane_first" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ips["01"]
  config_patches = [
    templatefile("${path.module}/templates/controlplane_patch.tftpl", {
      hostname            = "${var.cluster_name}-cp-01"
      install_disk        = "/dev/sda"
      talos_install_image = var.talos_install_image
      talos_version       = var.talos_version
      ip_address          = "${var.controlplane_ips["01"]}/24"
      network_gateway     = var.talos_network_gateway
      vip_shared_ip       = var.talos_vip
    }),
  ]
}

# Other control plane nodes - depend on bootstrap
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = { for k, v in var.controlplane_ips : k => v if k != "01" }

  depends_on                  = [talos_machine_bootstrap.this]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value
  config_patches = [
    templatefile("${path.module}/templates/controlplane_patch.tftpl", {
      hostname            = "${var.cluster_name}-cp-${each.key}"
      install_disk        = "/dev/sda"
      talos_install_image = var.talos_install_image
      talos_version       = var.talos_version
      ip_address          = "${each.value}/24"
      network_gateway     = var.talos_network_gateway
      vip_shared_ip       = var.talos_vip
    }),
  ]
}

# Worker configurations
resource "talos_machine_configuration_apply" "worker" {
  for_each = var.worker_ips

  depends_on                  = [talos_machine_bootstrap.this]
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value
  apply_mode                  = "auto"
  config_patches = [
    templatefile("${path.module}/templates/worker_patch.tftpl", {
      hostname            = "${var.cluster_name}-worker-${each.key}"
      install_disk        = "/dev/sda"
      talos_install_image = var.talos_install_image
      talos_version       = var.talos_version
      ip_address          = "${each.value}/24"
      network_gateway     = var.talos_network_gateway
    }),
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.controlplane_first]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips["01"]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ips["01"]
  endpoint             = var.talos_vip
}
