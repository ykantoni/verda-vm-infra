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

output "ssh_commands" {
  description = "SSH commands for each node, usable from any machine with the matching private key. Skips host-key pinning entirely (not just accepting new keys) since Verda reuses IPs across unrelated VMs — a previous occupant's key would otherwise make this fail with \"REMOTE HOST IDENTIFICATION HAS CHANGED\"."
  value = {
    cp1     = "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@${module.cp1.ip}"
    worker1 = "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null root@${module.worker1.ip}"
  }
}

output "hourly_cost_usd" {
  description = "Combined price per hour of both nodes."
  value       = module.cp1.price_per_hour + module.worker1.price_per_hour
}

output "kubeconfig_command" {
  description = "Fetches the kubeconfig from the control-plane node and rewrites it to use the public IP, so kubectl works from outside Verda Cloud. Written to ~/verda_kubeconfig.yaml, in the local user's home directory, regardless of the current directory."
  value       = "ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null ${var.ssh_user}@${module.cp1.ip} cat /etc/rancher/rke2/rke2.yaml | sed 's/127.0.0.1/${module.cp1.ip}/' > ~/verda_kubeconfig.yaml"
}

output "api_server_url" {
  description = "Kubernetes API server address reachable from outside Verda Cloud."
  value       = "https://${module.cp1.ip}:6443"
}
