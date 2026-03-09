########################################################
# Admin credentials (Secret)
########################################################

resource "random_password" "grafana_admin" {
  length  = 24
  special = true
}

resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin-credentials"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "grafana"
      "app.kubernetes.io/managed-by"  = "terraform"
      "${var.project_name}/component" = "grafana"
    }
  }

  data = {
    admin-user     = var.admin_user
    admin-password = random_password.grafana_admin.result
  }

  type = "Opaque"
}

###############################################################################
# Grafana via Helm (official Grafana chart)
###############################################################################

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.helm_chart_version
  namespace  = var.namespace

  values = [
    yamlencode({
      admin = {
        existingSecret = kubernetes_secret.grafana_admin.metadata[0].name
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }

      persistence = merge(
        {
          enabled = true
          size    = var.storage_size
          type    = "pvc"
        },
        var.storage_class != null ? { storageClassName = var.storage_class } : {}
      )

      service = {
        type = "ClusterIP"
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      # Default datasource: Prometheus (internal cluster URL)
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = var.prometheus_url
              access    = "proxy"
              isDefault = true
            }
          ]
        }
      }
    })
  ]

  depends_on = [kubernetes_secret.grafana_admin]
}
