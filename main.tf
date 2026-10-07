resource "verda_ssh_key" "this" {
  name       = "${var.name_prefix}-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

# Shared secret the worker uses to join the control-plane's RKE2 cluster.
resource "random_password" "rke2_token" {
  length  = 48
  special = false
}

module "rke2_server_script" {
  source = "./modules/rke2"

  role         = "server"
  rke2_version = var.rke2_version
  token        = random_password.rke2_token.result
}

module "cp1" {
  source = "./modules/verda-vm"

  hostname       = "${var.name_prefix}-cp1"
  description    = "RKE2 control-plane node"
  instance_type  = var.cp_instance_type
  image          = var.image
  location       = var.location
  os_volume_size = var.os_volume_size
  ssh_key_ids    = [verda_ssh_key.this.id]
  startup_script = module.rke2_server_script.script
}

# Rendered only after cp1 exists, so the agent's join config can point at its IP.
module "rke2_agent_script" {
  source = "./modules/rke2"

  role         = "agent"
  rke2_version = var.rke2_version
  token        = random_password.rke2_token.result
  server_url   = "https://${module.cp1.ip}:9345"
}

module "worker1" {
  source = "./modules/verda-vm"

  hostname       = "${var.name_prefix}-worker1"
  description    = "RKE2 worker node"
  instance_type  = var.worker_instance_type
  image          = var.image
  location       = var.location
  os_volume_size = var.os_volume_size
  ssh_key_ids    = [verda_ssh_key.this.id]
  startup_script = module.rke2_agent_script.script
}
