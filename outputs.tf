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
  description = "SSH commands for each node, usable from any machine with the matching private key."
  value = {
    cp1     = "ssh root@${module.cp1.ip}"
    worker1 = "ssh root@${module.worker1.ip}"
  }
}

output "hourly_cost_usd" {
  description = "Combined price per hour of both nodes."
  value       = module.cp1.price_per_hour + module.worker1.price_per_hour
}
