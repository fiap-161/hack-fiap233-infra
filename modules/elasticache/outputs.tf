output "endpoint" {
  description = "Redis primary endpoint (host)"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.main.port
}

output "security_group_id" {
  description = "Security group ID of Redis cluster"
  value       = aws_security_group.redis.id
}
