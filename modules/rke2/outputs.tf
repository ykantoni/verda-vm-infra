output "script" {
  description = "Rendered startup script that installs and configures RKE2 for this node's role."
  sensitive   = true
  value = var.role == "server" ? templatefile("${path.module}/scripts/rke2-server.sh.tftpl", {
    rke2_version = var.rke2_version
    token        = var.token
    }) : templatefile("${path.module}/scripts/rke2-agent.sh.tftpl", {
    rke2_version = var.rke2_version
    token        = var.token
    server_url   = var.server_url
  })
}
