output "talosconfig" {
  description = "Talos client configuration"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Kubernetes client configuration"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "worker_03_machineconfig" {
  description = "Worker 03 machine configuration"
  value       = talos_machine_configuration_apply.worker["03"].machine_configuration
  sensitive   = true
}

output "worker_04_machineconfig" {
  description = "Worker 04 machine configuration"
  value       = talos_machine_configuration_apply.worker["04"].machine_configuration
  sensitive   = true
}

output "worker_05_machineconfig" {
  description = "Worker 05 machine configuration"
  value       = talos_machine_configuration_apply.worker["05"].machine_configuration
  sensitive   = true
}

output "worker_06_machineconfig" {
  description = "Worker 06 machine configuration"
  value       = talos_machine_configuration_apply.worker["06"].machine_configuration
  sensitive   = true
}

output "worker_07_machineconfig" {
  description = "Worker 07 machine configuration"
  value       = talos_machine_configuration_apply.worker["07"].machine_configuration
  sensitive   = true
}

