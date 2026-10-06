variable "instance_count" {
  description = "Number of CPU VMs to create."
  type        = number
  default     = 2
}

variable "name_prefix" {
  description = "Prefix for instance hostnames (e.g. k8s-node-1, k8s-node-2)."
  type        = string
  default     = "k8s-node"
}

variable "instance_type" {
  description = "Verda CPU instance type. Examples: CPU.4V.16G, CPU.8V.32G, CPU-TURIN.4V.16G."
  type        = string
  default     = "CPU.4V.16G"
}

variable "image" {
  description = "Verda Kubernetes OS image. Other versions: 26.04.cuda13.2.kubernetes-1.33.13, -1.34.9, -1.35.8, -1.37.0."
  type        = string
  default     = "26.04.cuda13.2.kubernetes-1.36.4"
}

variable "location" {
  description = "Verda location code (FIN-01, FIN-02, FIN-03)."
  type        = string
  default     = "FIN-01"
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
