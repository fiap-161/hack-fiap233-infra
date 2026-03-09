variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Grafana (same as Prometheus: monitoring)"
  type        = string
  default     = "monitoring"
}

variable "prometheus_url" {
  description = "Internal URL of Prometheus for the Grafana datasource"
  type        = string
}

variable "helm_chart_version" {
  description = "Version of the Grafana Helm chart"
  type        = string
  default     = "8.3.3"
}

variable "storage_size" {
  description = "Persistent volume size for Grafana data/dashboards"
  type        = string
  default     = "2Gi"
}

variable "storage_class" {
  description = "StorageClass for Grafana PVC (null = cluster default)"
  type        = string
  default     = null
}

variable "admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}
