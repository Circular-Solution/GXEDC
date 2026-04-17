module "consumer-connector" {
  source            = "../shared/modules/connector"
  humanReadableName = "consumer"
  participantId     = var.consumer-did
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_consumer_edc"
  }
  vault-url              = "http://consumer-vault:8200"
  namespace              = kubernetes_namespace.ns.metadata.0.name
  sts-token-url          = "${module.consumer-identityhub.sts-token-url}/token"
  useSVE                 = var.useSVE
  participant-list-file  = "../shared/assets/participants/participants.local.json"
  gx_basic_functions_url = module.gx_basic_functions.service_url
  aliases = {
    sts-private-key   = "key-1"
    sts-public-key-id = "key-1"
  }
  depends_on = [kubernetes_job.rds-init]
}

module "consumer-identityhub" {
  depends_on        = [module.consumer-vault, kubernetes_job.rds-init]
  source            = "../shared/modules/identity-hub"
  humanReadableName = "consumer-identityhub"
  participantId     = var.consumer-did
  vault-url         = "http://consumer-vault:8200"
  service-name      = "consumer"
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_consumer_edc"
  }
  namespace = kubernetes_namespace.ns.metadata.0.name
  useSVE    = var.useSVE
  aliases = {
    sts-private-key   = "key-1"
    sts-public-key-id = "key-1"
  }

  gxdch_public_did     = "did:web:zhen.software"
  gxdch_base_id        = "https://zhen.software"
  gxdch_legal_name     = var.gxdch_legal_name
  gxdch_country_code   = var.gxdch_country_code
  gxdch_lei            = var.gxdch_lei
  gxdch_notary_url     = "http://host.docker.internal:3002"
  gxdch_compliance_url = "http://host.docker.internal:3001"
}

module "consumer-vault" {
  source            = "../shared/modules/vault"
  humanReadableName = "consumer-vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}
