resource "kubernetes_ingress_v1" "edc-ingress" {
  metadata {
    name      = "edc-ingress"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "consumer.local"
      http {
        path {
          path      = "/api/management"
          path_type = "Prefix"
          backend {
            service {
              name = "consumer-controlplane"
              port { number = 8081 }
            }
          }
        }
        path {
          path      = "/api/dsp"
          path_type = "Prefix"
          backend {
            service {
              name = "consumer-controlplane"
              port { number = 8082 }
            }
          }
        }
        path {
          path      = "/api/public"
          path_type = "Prefix"
          backend {
            service {
              name = "consumer-dataplane"
              port { number = 11002 }
            }
          }
        }
        path {
          path      = "/api/identity"
          path_type = "Prefix"
          backend {
            service {
              name = "consumer-identityhub"
              port { number = 7081 }
            }
          }
        }
        path {
          path      = "/api/credentials"
          path_type = "Prefix"
          backend {
            service {
              name = "consumer-identityhub"
              port { number = 7082 }
            }
          }
        }
      }
    }

    rule {
      host = "provider.local"
      http {
        path {
          path      = "/api/management"
          path_type = "Prefix"
          backend {
            service {
              name = "provider-controlplane"
              port { number = 8081 }
            }
          }
        }
        path {
          path      = "/api/dsp"
          path_type = "Prefix"
          backend {
            service {
              name = "provider-controlplane"
              port { number = 8082 }
            }
          }
        }
        path {
          path      = "/api/public"
          path_type = "Prefix"
          backend {
            service {
              name = "provider-dataplane"
              port { number = 11002 }
            }
          }
        }
        path {
          path      = "/api/identity"
          path_type = "Prefix"
          backend {
            service {
              name = "provider-identityhub"
              port { number = 7081 }
            }
          }
        }
        path {
          path      = "/api/credentials"
          path_type = "Prefix"
          backend {
            service {
              name = "provider-identityhub"
              port { number = 7082 }
            }
          }
        }
      }
    }
  }
}
