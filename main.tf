resource "verda_ssh_key" "this" {
  name       = "${var.name_prefix}-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

module "cp1" {
  source = "./modules/verda-vm"

  hostname       = "${var.name_prefix}-cp1"
  description    = "Kubernetes control-plane node"
  instance_type  = var.cp_instance_type
  image          = var.image
  location       = var.location
  os_volume_size = var.os_volume_size
  ssh_key_ids    = [verda_ssh_key.this.id]
}

module "worker1" {
  source = "./modules/verda-vm"

  hostname       = "${var.name_prefix}-worker1"
  description    = "Kubernetes worker node"
  instance_type  = var.worker_instance_type
  image          = var.image
  location       = var.location
  os_volume_size = var.os_volume_size
  ssh_key_ids    = [verda_ssh_key.this.id]
}

# Shared secret the worker uses to join the control-plane's RKE2 cluster.
resource "random_password" "rke2_token" {
  length  = 48
  special = false
}

module "rke2_server" {
  source = "./modules/rke2"

  role                 = "server"
  rke2_version         = var.rke2_version
  token                = random_password.rke2_token.result
  host                 = module.cp1.ip
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  pod_cidr             = var.pod_cidr
  service_cidr         = var.service_cidr
  cilium_cluster_name  = var.cilium_cluster_name
  longhorn_version     = var.longhorn_version
}

module "rke2_agent" {
  source = "./modules/rke2"

  role                 = "agent"
  rke2_version         = var.rke2_version
  token                = random_password.rke2_token.result
  server_url           = "https://${module.cp1.ip}:9345"
  host                 = module.worker1.ip
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path

  # The agent needs the server already accepting connections on :9345.
  depends_on = [module.rke2_server]
}

# Fetches RKE2's kubeconfig to a static local path (so the helm provider in
# verda-k8s-infra, which points at this path, gets a plan-time-known
# string — only the file's content is apply-time dependent).
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [module.rke2_server, module.rke2_agent]

  triggers = {
    cp1_ip = module.cp1.ip
  }

  provisioner "local-exec" {
    # UserKnownHostsFile=/dev/null: Verda reuses IPs across VMs, so
    # known_hosts may hold a *different* host's key for this address —
    # accept-new alone refuses to connect in that case (correctly treating
    # it as a changed key), so there's nothing worth pinning here anyway.
    # set -o pipefail (needs bash — /bin/sh here is dash, which lacks it):
    # without it, a failed ssh still lets `sed`/the redirect "succeed" on
    # empty input, silently writing an empty file instead of erroring.
    interpreter = ["/bin/bash", "-c"]
    command     = "set -o pipefail; ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ${var.ssh_user}@${module.cp1.ip} cat /etc/rancher/rke2/rke2.yaml | sed 's/127.0.0.1/${module.cp1.ip}/' > ${path.module}/.terraform-kubeconfig.yaml"
  }
}
