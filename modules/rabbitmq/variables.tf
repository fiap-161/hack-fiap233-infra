variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for RabbitMQ"
  type        = string
  default     = "messaging"
}

variable "rabbitmq_username" {
  description = "RabbitMQ username for application connections"
  type        = string
  default     = "application"
}

variable "queue_process" {
  description = "Name of the queue for video processing jobs"
  type        = string
  default     = "video.process"
}

variable "queue_dlq" {
  description = "Name of the dead-letter queue for failed jobs"
  type        = string
  default     = "video.process.dlq"
}

variable "helm_chart_version" {
  description = "Version of the Bitnami RabbitMQ Helm chart"
  type        = string
  default     = "14.0.0"
}

variable "replica_count" {
  description = "Number of RabbitMQ replicas (1 for simplicity in hackathon)"
  type        = number
  default     = 1
}
