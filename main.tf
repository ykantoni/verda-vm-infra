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
