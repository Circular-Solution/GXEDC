module "consumer-connector" {
  source            = "./modules/connector"
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
  participant-list-file  = "./assets/participants/participants.local.json"
  gx_basic_functions_url = var.gx_basic_functions_url
  depends_on             = [kubernetes_job.rds-init]
  node-port-base         = 32000
  use-https              = var.use-https
  dataplane-public-url   = var.consumer-dataplane-public-url
}

module "consumer-identityhub" {
  depends_on        = [module.consumer-vault, kubernetes_job.rds-init]
  source            = "./modules/identity-hub"
  humanReadableName = "consumer-identityhub"
  participantId     = var.consumer-did
  vault-url         = "http://consumer-vault:8200"
  service-name      = "consumer"
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_consumer_edc"
  }
  namespace      = kubernetes_namespace.ns.metadata.0.name
  useSVE         = var.useSVE
  node-port-base = 32000
  use-https      = var.use-https
}

module "consumer-vault" {
  source            = "./modules/vault"
  humanReadableName = "consumer-vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}
