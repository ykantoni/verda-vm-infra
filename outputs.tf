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

output "ssh_commands" {
  description = "SSH commands for each node, usable from any machine with the matching private key."
  value = {
    cp1     = "ssh root@${module.cp1.ip}"
    worker1 = "ssh root@${module.worker1.ip}"
  }
}

output "kubeconfig_command" {
  description = "Fetches the kubeconfig from cp1 and rewrites it to use the public IP, so kubectl works from outside Verda Cloud."
  value       = "ssh root@${module.cp1.ip} cat /etc/rancher/rke2/rke2.yaml | sed 's/127.0.0.1/${module.cp1.ip}/' > kubeconfig.yaml"
}

output "api_server_url" {
  description = "Kubernetes API server address reachable from outside Verda Cloud."
  value       = "https://${module.cp1.ip}:6443"
}

output "hourly_cost_usd" {
  description = "Combined price per hour of both nodes."
  value       = module.cp1.price_per_hour + module.worker1.price_per_hour
}
