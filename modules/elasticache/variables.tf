variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Redis will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the ElastiCache subnet group (private subnets)"
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group ID allowed to connect to Redis (e.g. EKS nodes)"
  type        = string
}

variable "node_type" {
  description = "ElastiCache node type (e.g. cache.t3.micro, cache.t4g.micro)"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes (1 = single node, no replica)"
  type        = number
  default     = 1
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "port" {
  description = "Redis port"
  type        = number
  default     = 6379
}
