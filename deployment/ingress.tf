// Identity and credentials APIs of the shared hub. The identity-hub module also
// publishes prefixed routes, but its DID rule overlaps them, so provisioning uses these.
resource "kubernetes_ingress_v1" "identity-api-ingress" {
  count = length(var.identityhub-hosts) > 0 ? 1 : 0

  metadata {
    name      = "edc-identity-ingress"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }

  spec {
    ingress_class_name = "nginx"

    dynamic "rule" {
      for_each = var.identityhub-hosts
      content {
        host = rule.value
        http {
          path {
            path      = "/api/identity"
            path_type = "Prefix"
            backend {
              service {
                name = "identityhub"
                port { number = 7081 }
              }
            }
          }
          path {
            path      = "/api/credentials"
            path_type = "Prefix"
            backend {
              service {
                name = "identityhub"
                port { number = 7082 }
              }
            }
          }
        }
      }
    }
  }
}
