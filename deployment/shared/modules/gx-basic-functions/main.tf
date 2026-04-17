locals {
  deploy_in_cluster = var.enabled && var.external_url == ""
}

resource "kubernetes_deployment" "gx_basic_functions" {
  count = local.deploy_in_cluster ? 1 : 0

  metadata {
    name      = var.humanReadableName
    namespace = var.namespace
    labels = {
      App = var.humanReadableName
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        App = var.humanReadableName
      }
    }

    template {
      metadata {
        labels = {
          App = var.humanReadableName
        }
      }
      spec {
        container {
          image_pull_policy = var.image_pull_policy
          image             = var.image
          name              = var.humanReadableName

          env {
            name  = "BASE_URL"
            value = "http://${var.humanReadableName}:${var.container_port}"
          }
          env {
            name  = "APP_PATH"
            value = ""
          }
          env {
            name  = "REGISTRY_URL"
            value = var.registry_url
          }

          port {
            container_port = var.container_port
            name           = "http"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 5
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "gx_basic_functions" {
  count = local.deploy_in_cluster ? 1 : 0

  metadata {
    name      = var.humanReadableName
    namespace = var.namespace
  }

  spec {
    selector = {
      App = var.humanReadableName
    }
    port {
      port        = var.container_port
      target_port = var.container_port
      name        = "http"
    }
    type = "ClusterIP"
  }
}
