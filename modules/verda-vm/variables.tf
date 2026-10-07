variable "hostname" {
  description = "Hostname of the VM."
  type        = string
}

variable "description" {
  description = "Description shown in the Verda console."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Verda instance type, e.g. CPU.4V.16G, CPU.8V.32G, CPU-TURIN.4V.16G."
  type        = string
}

variable "image" {
  description = "Verda OS image type."
  type        = string
}

variable "location" {
  description = "Verda location code (FIN-01, FIN-02, FIN-03)."
  type        = string
}

variable "os_volume_size" {
  description = "OS volume size in GB."
  type        = number
  default     = 100
}

variable "ssh_key_ids" {
  description = "SSH key IDs to install on the VM."
  type        = list(string)
}

variable "startup_script" {
  description = "Raw script content to run once at first boot. Set to null to skip."
  type        = string
  default     = null
  sensitive   = true
}
