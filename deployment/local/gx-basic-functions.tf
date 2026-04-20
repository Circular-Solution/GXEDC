module "gx_basic_functions" {
  source    = "../shared/modules/gx-basic-functions"
  namespace = kubernetes_namespace.ns.metadata.0.name

  enabled      = var.gx_basic_functions_enabled
  registry_url = var.gxdch_registry_url
}
