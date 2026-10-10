output "cp1" {
  description = "Hostname, ID, public IP and status of the control-plane node."
  value = {
    id     = module.cp1.id
    ip     = module.cp1.ip
    status = module.cp1.status
  }
}

output "worker1" {
  description = "Hostname, ID, public IP and status of the worker node."
  value = {
    id     = module.worker1.id
    ip     = module.worker1.ip
    status = module.worker1.status
  }
}

output "cp1_ip" {
  description = "Public IP of the control-plane node, in a form easy to consume from another repo (terraform output -raw cp1_ip)."
  value       = module.cp1.ip
}

output "worker1_ip" {
  description = "Public IP of the worker node, in a form easy to consume from another repo (terraform output -raw worker1_ip)."
  value       = module.worker1.ip
}

output "gpu1" {
  description = "Hostname, ID, public IP and status of the optional GPU worker node (null unless create_gpu_node = true)."
  value = var.create_gpu_node ? {
    id     = module.gpu1[0].id
    ip     = module.gpu1[0].ip
    status = module.gpu1[0].status
  } : null
}

output "gpu1_ip" {
  description = "Public IP of the optional GPU worker node (null unless create_gpu_node = true)."
  value       = var.create_gpu_node ? module.gpu1[0].ip : null
}

output "ssh_commands" {
  description = "SSH commands for each node, usable from any machine with the matching private key. Skips host-key pinning entirely (not just accepting new keys) since Verda reuses IPs across unrelated VMs — a previous occupant's key would otherwise make this fail with \"REMOTE HOST IDENTIFICATION HAS CHANGED\"."
  value = merge(
    {
      cp1     = "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@${module.cp1.ip}"
      worker1 = "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@${module.worker1.ip}"
    },
    var.create_gpu_node ? {
      gpu1 = "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@${module.gpu1[0].ip}"
    } : {}
  )
}

output "hourly_cost_usd" {
  description = "Combined price per hour of all nodes (including the GPU node, if created)."
  value       = module.cp1.price_per_hour + module.worker1.price_per_hour + (var.create_gpu_node ? module.gpu1[0].price_per_hour : 0)
}

output "kubeconfig_command" {
  description = "Fetches the kubeconfig from the control-plane node, rewrites it to use the public IP so kubectl works from outside Verda Cloud, and renames RKE2's hardcoded \"default\" cluster/context/user entries to cilium_cluster_name — purely a local label in this file; unrelated to (and doesn't affect) Cilium's own cluster identity, which is already set via the HelmChartConfig in the rke2 module. Written to ~/verda_kubeconfig.yaml, in the local user's home directory, regardless of the current directory."
  value       = "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${module.cp1.ip} cat /etc/rancher/rke2/rke2.yaml | sed -e 's/127.0.0.1/${module.cp1.ip}/' -e 's/ default/ ${var.cilium_cluster_name}/g' > ~/verda_kubeconfig.yaml"
}

output "api_server_url" {
  description = "Kubernetes API server address reachable from outside Verda Cloud."
  value       = "https://${module.cp1.ip}:6443"
}
