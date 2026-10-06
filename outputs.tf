output "instances" {
  description = "Hostname, ID, public IP and status of each VM."
  value = {
    for i in verda_instance.k8s : i.hostname => {
      id     = i.id
      ip     = i.ip
      status = i.status
    }
  }
}

output "ssh_commands" {
  description = "SSH commands for each VM."
  value       = [for i in verda_instance.k8s : "ssh root@${i.ip}"]
}

output "hourly_cost_usd" {
  description = "Combined price per hour of all VMs."
  value       = sum([for i in verda_instance.k8s : i.price_per_hour])
}
