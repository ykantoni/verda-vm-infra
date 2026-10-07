output "id" {
  description = "Verda instance ID."
  value       = verda_instance.this.id
}

output "hostname" {
  description = "Hostname of the VM."
  value       = verda_instance.this.hostname
}

output "ip" {
  description = "Public IP address of the VM."
  value       = verda_instance.this.ip
}

output "status" {
  description = "Current status of the VM."
  value       = verda_instance.this.status
}

output "price_per_hour" {
  description = "Price per hour of the VM, in USD."
  value       = verda_instance.this.price_per_hour
}
