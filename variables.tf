###############################################################################
# General
###############################################################################

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "hack-fiap233"
}

###############################################################################
# VPC
###############################################################################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for the subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

###############################################################################
# EKS
###############################################################################

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 3
}

###############################################################################
# NLB / Service Ports
###############################################################################

variable "nlb_port_users" {
  description = "NLB listener port for the users service"
  type        = number
  default     = 8081
}

variable "nlb_port_videos" {
  description = "NLB listener port for the videos service"
  type        = number
  default     = 8082
}

variable "node_port_users" {
  description = "Kubernetes NodePort for the users service"
  type        = number
  default     = 30081
}

variable "node_port_videos" {
  description = "Kubernetes NodePort for the videos service"
  type        = number
  default     = 30082
}

###############################################################################
# RDS
###############################################################################

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS instances in GB"
  type        = number
  default     = 20
}

variable "rds_db_username" {
  description = "Master username for the RDS instances"
  type        = string
  default     = "dbadmin"
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version for RDS"
  type        = string
  default     = "16.6"
}

###############################################################################
# RabbitMQ (mensageria)
###############################################################################

variable "rabbitmq_namespace" {
  description = "Kubernetes namespace for RabbitMQ"
  type        = string
  default     = "messaging"
}

variable "rabbitmq_username" {
  description = "RabbitMQ username for application connections"
  type        = string
  default     = "application"
}

variable "rabbitmq_queue_process" {
  description = "Queue name for video processing jobs"
  type        = string
  default     = "video.process"
}

variable "rabbitmq_queue_dlq" {
  description = "Dead-letter queue name for failed jobs"
  type        = string
  default     = "video.process.dlq"
}

variable "rabbitmq_helm_chart_version" {
  description = "Bitnami RabbitMQ Helm chart version"
  type        = string
  default     = "14.0.0"
}

variable "rabbitmq_replica_count" {
  description = "Number of RabbitMQ replicas (1 for simplicity)"
  type        = number
  default     = 1
}

###############################################################################
# Redis (Cache)
###############################################################################

variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_clusters" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

###############################################################################
# Notificação (SNS + Lambda + SES) — erro processamento de vídeo
###############################################################################

variable "notification_topic_name" {
  description = "SNS topic name for video processing failure events"
  type        = string
  default     = "video-processing-failed"
}

variable "ses_sender_email" {
  description = "SES sender email (must be verified in SES console; in sandbox, recipient emails must also be verified)"
  type        = string
}

variable "notification_email_subject" {
  description = "Subject line for video processing failure notification email"
  type        = string
  default     = "FiapX Videos — Erro no processamento do seu vídeo"
}
