variable "name_prefix" {
  description = "Prefix for instance hostnames (e.g. k8s-cp1, k8s-worker1)."
  type        = string
  default     = "k8s"
}

variable "cp_instance_type" {
  description = "Verda CPU instance type for the control-plane node. Examples: CPU.4V.16G, CPU.8V.32G, CPU-TURIN.4V.16G."
  type        = string
  default     = "CPU.4V.16G"
}

variable "worker_instance_type" {
  description = "Verda CPU instance type for the worker node. Examples: CPU.4V.16G, CPU.8V.32G, CPU-TURIN.4V.16G."
  type        = string
  default     = "CPU.4V.16G"
}

variable "image" {
  description = "Verda OS image. A plain Ubuntu image is used; Kubernetes is installed separately by verda-k8s-infra."
  type        = string
  default     = "26.04.base"
}

variable "location" {
  description = "Verda location code (FIN-01, FIN-02, FIN-03). Check `verda availability` first — not every location has spare capacity for every instance type at any given time."
  type        = string
  default     = "FIN-03"
}

variable "os_volume_size" {
  description = "OS volume size in GB."
  type        = number
  default     = 100
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key added to the instances."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
