resource "verda_ssh_key" "this" {
  name       = "${var.name_prefix}-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "verda_instance" "k8s" {
  count = var.instance_count

  hostname      = "${var.name_prefix}-${count.index + 1}"
  description   = "Kubernetes CPU node ${count.index + 1}"
  instance_type = var.instance_type
  image         = var.image
  location      = var.location
  ssh_key_ids   = [verda_ssh_key.this.id]

  os_volume = {
    name       = "${var.name_prefix}-${count.index + 1}-os"
    size       = var.os_volume_size
    type       = "NVMe"
    on_destroy = "delete_permanently"
  }
}
