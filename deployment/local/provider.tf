module "provider-connector" {
  source            = "../shared/modules/connector"
  humanReadableName = "provider"
  participantId     = var.provider-did
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_provider_edc"
  }
  namespace              = kubernetes_namespace.ns.metadata.0.name
  vault-url              = "http://provider-vault:8200"
  sts-token-url          = "${module.provider-identityhub.sts-token-url}/token"
  useSVE                 = var.useSVE
  participant-list-file  = "../shared/assets/participants/participants.local.json"
  gx_basic_functions_url = module.gx_basic_functions.service_url
  depends_on             = [kubernetes_job.rds-init]
}

module "provider-identityhub" {
  depends_on        = [module.provider-vault, kubernetes_job.rds-init]
  source            = "../shared/modules/identity-hub"
  humanReadableName = "provider-identityhub"
  participantId     = var.provider-did
  vault-url         = "http://provider-vault:8200"
  service-name      = "provider"
  namespace         = kubernetes_namespace.ns.metadata.0.name
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_identity_edc"
  }
  useSVE = var.useSVE
}

module "provider-catalog-server" {
  source                = "../shared/modules/catalog-server"
  humanReadableName     = "provider-catalog-server"
  participantId         = var.provider-did
  namespace             = kubernetes_namespace.ns.metadata.0.name
  vault-url             = "http://provider-vault:8200"
  sts-token-url         = "${module.provider-identityhub.sts-token-url}/token"
  participant-list-file = "../shared/assets/participants/participants.local.json"
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_catalogserver_edc"
  }
  useSVE     = var.useSVE
  depends_on = [kubernetes_job.rds-init]
}

module "provider-vault" {
  source            = "../shared/modules/vault"
  humanReadableName = "provider-vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}
