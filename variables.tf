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

variable "ssh_user" {
  description = "SSH user used to connect to both nodes to bootstrap RKE2."
  type        = string
  default     = "root"
}

variable "ssh_private_key_path" {
  description = "Path to the private key matching ssh_public_key_path."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "rke2_version" {
  description = "RKE2 version to install, e.g. v1.31.4+rke2r1. Pinned rather than left empty: the install script's \"latest stable\" auto-resolution depends on update.rke2.io/v1-release/channels, which has been returning 404 (an upstream outage, not this repo) — pinning a real tag bypasses it entirely."
  type        = string
  default     = "v1.37.1+rke2r1"
}

variable "pod_cidr" {
  description = "Pod IP address range (cluster-cidr)."
  type        = string
  default     = "1.1.0.0/16"
}

variable "service_cidr" {
  description = "Service IP address range (service-cidr)."
  type        = string
  default     = "2.2.0.0/16"
}

variable "cilium_cluster_name" {
  description = "Cilium's cluster identity name (cluster.name Helm value)."
  type        = string
  default     = "verdaclu"
}
