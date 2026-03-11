###############################################################################
# API Gateway
###############################################################################

output "api_gateway_url" {
  description = "Public URL of the API Gateway (entry point for clients)"
  value       = module.api_gateway.api_endpoint
}

###############################################################################
# EKS
###############################################################################

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

###############################################################################
# NLB
###############################################################################

output "nlb_dns_name" {
  description = "DNS name of the internal NLB"
  value       = module.nlb.nlb_dns_name
}

###############################################################################
# RDS
###############################################################################

output "rds_users_endpoint" {
  description = "Endpoint of the Users RDS instance"
  value       = module.rds_users.db_endpoint
}

output "rds_videos_endpoint" {
  description = "Endpoint of the Videos RDS instance"
  value       = module.rds_videos.db_endpoint
}

output "rds_users_secret_name" {
  description = "Secrets Manager secret name for Users DB credentials"
  value       = module.rds_users.secret_name
}

output "rds_videos_secret_name" {
  description = "Secrets Manager secret name for Videos DB credentials"
  value       = module.rds_videos.secret_name
}

###############################################################################
# ECR
###############################################################################

output "ecr_users_url" {
  description = "ECR repository URL for the users service"
  value       = aws_ecr_repository.users.repository_url
}

output "ecr_videos_url" {
  description = "ECR repository URL for the videos service"
  value       = aws_ecr_repository.videos.repository_url
}

###############################################################################
# VPC
###############################################################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

###############################################################################
# JWT
###############################################################################

output "jwt_secret_name" {
  description = "Secrets Manager secret name for JWT signing key"
  value       = aws_secretsmanager_secret.jwt_secret.name
}

output "jwt_secret_arn" {
  description = "Secrets Manager secret ARN for JWT signing key"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

###############################################################################
# RabbitMQ (mensageria)
###############################################################################

output "rabbitmq_host" {
  description = "RabbitMQ host (K8s service DNS) for AMQP connections from pods"
  value       = module.rabbitmq.host
}

output "rabbitmq_port" {
  description = "RabbitMQ AMQP port"
  value       = module.rabbitmq.port
}

output "rabbitmq_queue_process" {
  description = "Queue name for video processing jobs (use in Videos service)"
  value       = module.rabbitmq.queue_process
}

output "rabbitmq_queue_dlq" {
  description = "Dead-letter queue name for failed jobs"
  value       = module.rabbitmq.queue_dlq
}

output "rabbitmq_secret_name" {
  description = "Secrets Manager secret name for RabbitMQ credentials"
  value       = module.rabbitmq.secret_name
}

output "rabbitmq_secret_arn" {
  description = "Secrets Manager secret ARN for RabbitMQ credentials"
  value       = module.rabbitmq.secret_arn
}

output "rabbitmq_namespace" {
  description = "Kubernetes namespace where RabbitMQ is deployed"
  value       = module.rabbitmq.namespace
}

###############################################################################
# Redis (cache)
###############################################################################

output "redis_endpoint" {
  description = "Redis primary endpoint (host) for applications in EKS"
  value       = module.elasticache_redis.endpoint
}

output "redis_port" {
  description = "Redis port"
  value       = module.elasticache_redis.port
}

#####################################################################
# Notificação (SNS + Lambda + SES)
######################################################################

output "notification_sns_topic_arn" {
  description = "ARN of the SNS topic for video-processing-failed (Videos worker publishes here on failure)"
  value       = module.notification.sns_topic_arn
}

output "notification_sns_topic_name" {
  description = "Name of the SNS topic for failure notifications"
  value       = module.notification.sns_topic_name
}
