output "namespace" {
  description = "Kubernetes namespace where Prometheus is deployed"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "service_name" {
  description = "Prometheus server Service name (for Grafana datasource URL)"
  value       = "prometheus-server"
}

output "service_port" {
  description = "Prometheus server Service port"
  value       = 80
}

output "prometheus_url" {
  description = "Internal URL for Prometheus"
  value       = "http://prometheus-server.${var.namespace}.svc.cluster.local:80"
}
