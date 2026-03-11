########### Kubernetes namespace for monitoring (Prometheus) ###########

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"       = "monitoring"
      "app.kubernetes.io/managed-by" = "terraform"
      "${var.project_name}/component" = "prometheus"
    }
  }
}


############ Prometheus via Helm (prometheus-community) ###########

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = var.helm_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode({
      rbac = {
        create = true
      }

      server = {
        name = "server"

        persistentVolume = merge(
          {
            enabled     = true
            size        = var.storage_size
            accessModes = ["ReadWriteOnce"]
            mountPath   = "/data"
          },
          var.storage_class != null ? { storageClass = var.storage_class } : {}
        )

        retention = var.retention

        resources = {
          requests = {
            cpu    = "100m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }

        service = {
          type = "ClusterIP"
        }
      }

      # Chart default: kubernetes-pods e kubernetes-service-endpoints discovery
      # (Pods/Services com prometheus.io/scrape, prometheus.io/port, prometheus.io/path)

      alertmanager = {
        enabled = false
      }
      pushgateway = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}
