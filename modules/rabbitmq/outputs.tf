output "namespace" {
  description = "Kubernetes namespace where RabbitMQ is deployed"
  value       = kubernetes_namespace.messaging.metadata[0].name
}

output "host" {
  description = "RabbitMQ host (K8s service DNS) for AMQP connections"
  value       = "rabbitmq.${var.namespace}.svc.cluster.local"
}

output "port" {
  description = "RabbitMQ AMQP port"
  value       = 5672
}

output "queue_process" {
  description = "Name of the queue for video processing jobs"
  value       = var.queue_process
}

output "queue_dlq" {
  description = "Name of the dead-letter queue for failed jobs"
  value       = var.queue_dlq
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret with RabbitMQ credentials"
  value       = aws_secretsmanager_secret.rabbitmq_credentials.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret with RabbitMQ credentials"
  value       = aws_secretsmanager_secret.rabbitmq_credentials.name
}
