module "gx_basic_functions" {
  source    = "../shared/modules/gx-basic-functions"
  namespace = kubernetes_namespace.ns.metadata.0.name

  enabled      = false # enable for strict gxdch checking
  registry_url = "http://host.docker.internal:3004"
}
