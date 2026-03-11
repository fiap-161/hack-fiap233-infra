output "namespace" {
  description = "Kubernetes namespace where Grafana is deployed"
  value       = var.namespace
}

output "service_name" {
  description = "Grafana Service name (for port-forward)"
  value       = "grafana"
}

output "grafana_url" {
  description = "Internal URL for Grafana (http://service.namespace.svc.cluster.local)"
  value       = "http://grafana.${var.namespace}.svc.cluster.local"
}

output "admin_secret_name" {
  description = "Name of the Secret containing Grafana admin credentials (admin-user, admin-password)"
  value       = kubernetes_secret.grafana_admin.metadata[0].name
}
