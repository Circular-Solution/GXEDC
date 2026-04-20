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

  gxdch_public_did             = var.gxdch_public_did
  gxdch_base_id                = var.gxdch_domain
  gxdch_legal_name             = var.gxdch_legal_name
  gxdch_country_code           = var.gxdch_country_code
  gxdch_lei                    = var.gxdch_lei
  gxdch_notary_url             = var.gxdch_notary_url
  gxdch_compliance_url         = var.gxdch_compliance_url
  gxdch_verification_method_id = var.gxdch_verification_method_id
  gxdch_s3_bucket              = var.gxdch_s3_bucket
  gxdch_s3_region              = var.gxdch_s3_region

  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
}

module "consumer-vault" {
  source            = "../shared/modules/vault"
  humanReadableName = "consumer-vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}
