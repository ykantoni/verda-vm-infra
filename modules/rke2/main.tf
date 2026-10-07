check "agent_requires_server_url" {
  assert {
    condition     = var.role != "agent" || var.server_url != null
    error_message = "server_url is required when role = \"agent\"."
  }
}
