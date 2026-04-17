output "service_url" {
  description = "URL to use for gx-basic-functions calls. Empty string if disabled"
  value       = var.external_url != "" ? var.external_url : (var.enabled ? "http://${var.humanReadableName}:${var.container_port}" : "")
}

output "enabled" {
  value = var.enabled
}
