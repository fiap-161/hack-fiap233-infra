terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # The bucket must exist before running terraform init.
  # Create it first by running: cd bootstrap && terraform init && terraform apply
  backend "s3" {
    bucket = "hack-fiap233-tfstate"
    key    = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# Kubernetes and Helm providers for EKS (used by RabbitMQ module).
# Data sources depend on EKS; run `terraform apply` twice if RabbitMQ fails on first run (cluster not ready).
data "aws_eks_cluster" "main" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

###############################################################################
# LabRole
###############################################################################

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

###############################################################################
# VPC
###############################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  node_port_users      = var.node_port_users
  node_port_videos     = var.node_port_videos
  nlb_port_users       = var.nlb_port_users
  nlb_port_videos      = var.nlb_port_videos
}

###############################################################################
# EKS
###############################################################################

module "eks" {
  source = "./modules/eks"

  project_name            = var.project_name
  cluster_role_arn        = data.aws_iam_role.lab_role.arn
  node_role_arn           = data.aws_iam_role.lab_role.arn
  subnet_ids              = module.vpc.private_subnet_ids
  node_security_group_ids = [module.vpc.sg_eks_nodes_id]
  node_instance_types     = var.node_instance_types
  node_desired_size       = var.node_desired_size
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  kubernetes_version      = var.kubernetes_version
}

###############################################################################
# NLB
###############################################################################

module "nlb" {
  source = "./modules/nlb"

  project_name         = var.project_name
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_ids   = [module.vpc.sg_nlb_id]
  nlb_port_users       = var.nlb_port_users
  nlb_port_videos      = var.nlb_port_videos
  node_port_users      = var.node_port_users
  node_port_videos     = var.node_port_videos
  node_group_asg_name  = module.eks.node_group_asg_name
}

###############################################################################
# JWT Secret (for Lambda Authorizer + Users service)
###############################################################################

resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "${var.project_name}/jwt-secret"
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

###############################################################################
# API Gateway
###############################################################################

module "api_gateway" {
  source = "./modules/api_gateway"

  project_name            = var.project_name
  subnet_ids              = module.vpc.private_subnet_ids
  security_group_ids      = [module.vpc.sg_vpc_link_id]
  nlb_listener_users_arn  = module.nlb.listener_users_arn
  nlb_listener_videos_arn = module.nlb.listener_videos_arn
  lambda_role_arn         = data.aws_iam_role.lab_role.arn
  jwt_secret              = random_password.jwt_secret.result
}

###############################################################################
# ECR Repositories
###############################################################################

resource "aws_ecr_repository" "users" {
  name         = "${var.project_name}-users"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-users"
  }
}

resource "aws_ecr_repository" "videos" {
  name         = "${var.project_name}-videos"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name = "${var.project_name}-videos"
  }
}

###############################################################################
# RDS — Users
###############################################################################

module "rds_users" {
  source = "./modules/rds"

  project_name       = var.project_name
  service_name       = "users"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.sg_rds_users_id]
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  db_name            = "usersdb"
  db_username        = var.rds_db_username
  engine_version     = var.rds_engine_version
}

###############################################################################
# RDS — Videos
###############################################################################

module "rds_videos" {
  source = "./modules/rds"

  project_name       = var.project_name
  service_name       = "videos"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.sg_rds_videos_id]
  instance_class     = var.rds_instance_class
  allocated_storage  = var.rds_allocated_storage
  db_name            = "videosdb"
  db_username        = var.rds_db_username
  engine_version     = var.rds_engine_version
}

###############################################################################
# Mensageria — RabbitMQ 
###############################################################################

module "rabbitmq" {
  source = "./modules/rabbitmq"

  project_name       = var.project_name
  namespace          = var.rabbitmq_namespace
  rabbitmq_username  = var.rabbitmq_username
  queue_process      = var.rabbitmq_queue_process
  queue_dlq          = var.rabbitmq_queue_dlq
  helm_chart_version = var.rabbitmq_helm_chart_version
  replica_count      = var.rabbitmq_replica_count

  depends_on = [module.eks]
}

###############################################################################
# Cache — ElastiCache Redis
###############################################################################

module "elasticache_redis" {
  source = "./modules/elasticache"

  project_name               = var.project_name
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_security_group_id  = module.vpc.sg_eks_nodes_id
  node_type                  = var.redis_node_type
  num_cache_clusters         = var.redis_num_cache_clusters
  engine_version             = var.redis_engine_version
  port                       = var.redis_port
}

###########################################################################
# Monitoramento — Prometheus (Fase 5)
###########################################################################

module "prometheus" {
  source = "./modules/prometheus"

  project_name       = var.project_name
  namespace          = var.prometheus_namespace
  helm_chart_version = var.prometheus_helm_chart_version
  retention          = var.prometheus_retention
  storage_size       = var.prometheus_storage_size
  storage_class      = var.prometheus_storage_class

  depends_on = [module.eks]
}

########################################################
# Monitoramento — Grafana
########################################################

module "grafana" {
  source = "./modules/grafana"

  project_name       = var.project_name
  namespace          = var.prometheus_namespace
  prometheus_url     = module.prometheus.prometheus_url
  admin_user          = var.grafana_admin_user
  helm_chart_version  = var.grafana_helm_chart_version
  storage_size        = var.grafana_storage_size
  storage_class       = var.grafana_storage_class

  depends_on = [module.prometheus]
}
