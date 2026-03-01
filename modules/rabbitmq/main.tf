###############################################################################
# Random password for RabbitMQ
###############################################################################

resource "random_password" "rabbitmq_password" {
  length  = 24
  special = false
}

###############################################################################
# Kubernetes namespace for messaging (RabbitMQ)
###############################################################################

resource "kubernetes_namespace" "messaging" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "messaging"
      "app.kubernetes.io/managed-by"  = "terraform"
      "${var.project_name}/component" = "rabbitmq"
    }
  }
}

###############################################################################
# RabbitMQ via Helm (Bitnami)
###############################################################################

resource "helm_release" "rabbitmq" {
  name       = "rabbitmq"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "rabbitmq"
  version    = var.helm_chart_version
  namespace  = kubernetes_namespace.messaging.metadata[0].name

  set {
    name  = "fullnameOverride"
    value = "rabbitmq"
  }

  set {
    name  = "auth.username"
    value = var.rabbitmq_username
  }

  set_sensitive {
    name  = "auth.password"
    value = random_password.rabbitmq_password.result
  }

  set {
    name  = "replicaCount"
    value = var.replica_count
  }

  # Persistência mínima para não perder mensagens em restart (opcional: desabilitar em dev)
  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.size"
    value = "2Gi"
  }

  # Serviço ClusterIP (acesso apenas dentro do cluster)
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  # Management plugin (porta 15672) para debug; desabilitar em prod se não precisar
  set {
    name  = "metrics.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.messaging]
}

###############################################################################
# Secrets Manager — credenciais e endpoint para os serviços (Videos, worker)
###############################################################################

resource "aws_secretsmanager_secret" "rabbitmq_credentials" {
  name = "${var.project_name}/rabbitmq/credentials"

  tags = {
    Name = "${var.project_name}-rabbitmq-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "rabbitmq_credentials" {
  secret_id = aws_secretsmanager_secret.rabbitmq_credentials.id

  secret_string = jsonencode({
    username   = var.rabbitmq_username
    password   = random_password.rabbitmq_password.result
    host       = "rabbitmq.${var.namespace}.svc.cluster.local"
    port       = 5672
    protocol   = "amqp"
    uri        = "amqp://${var.rabbitmq_username}:${random_password.rabbitmq_password.result}@rabbitmq.${var.namespace}.svc.cluster.local:5672/"
    queue      = var.queue_process
    queue_dlq  = var.queue_dlq
  })
}
