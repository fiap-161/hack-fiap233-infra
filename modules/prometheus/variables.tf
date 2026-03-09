variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for Prometheus (monitoring stack)"
  type        = string
  default     = "monitoring"
}

variable "helm_chart_version" {
  description = "Version of the prometheus-community Prometheus Helm chart"
  type        = string
  default     = "27.0.0"
}

variable "retention" {
  description = "Prometheus metrics retention period"
  type        = string
  default     = "15d"
}

variable "storage_size" {
  description = "Persistent volume size for Prometheus data"
  type        = string
  default     = "8Gi"
}

variable "storage_class" {
  description = "StorageClass for Prometheus PVC (empty = cluster default, e.g. gp3 on EKS)"
  type        = string
  default     = null
}
