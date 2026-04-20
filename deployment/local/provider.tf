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
  aliases = {
    sts-private-key   = "key-1"
    sts-public-key-id = "key-1"
  }
  depends_on = [kubernetes_job.rds-init]
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
  aliases = {
    sts-private-key   = "key-1"
    sts-public-key-id = "key-1"
  }

  gxdch_public_did             = var.gxdch_public_did
  gxdch_base_id                = var.gxdch_domain
  gxdch_legal_name             = var.gxdch_legal_name
  gxdch_country_code           = var.gxdch_country_code
  gxdch_lei                    = var.gxdch_lei
  gxdch_notary_url             = var.gxdch_notary_url
  gxdch_compliance_url         = var.gxdch_compliance_url
  gxdch_verification_method_id = var.gxdch_verification_method_id
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
  useSVE = var.useSVE
  aliases = {
    sts-private-key   = "key-1"
    sts-public-key-id = "key-1"
  }
  depends_on = [kubernetes_job.rds-init]
}

module "provider-vault" {
  source            = "../shared/modules/vault"
  humanReadableName = "provider-vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}
