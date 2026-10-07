resource "verda_startup_script" "this" {
  count  = var.startup_script == null ? 0 : 1
  name   = "${var.hostname}-startup"
  script = var.startup_script
}

resource "verda_instance" "this" {
  hostname          = var.hostname
  description       = var.description
  instance_type     = var.instance_type
  image             = var.image
  location          = var.location
  ssh_key_ids       = var.ssh_key_ids
  startup_script_id = var.startup_script == null ? null : verda_startup_script.this[0].id

  os_volume = {
    name       = "${var.hostname}-os"
    size       = var.os_volume_size
    type       = "NVMe"
    on_destroy = "delete_permanently"
  }
}
