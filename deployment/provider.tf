module "provider-catalog-server" {
  count                 = var.enable-catalog-server ? 1 : 0
  source                = "./modules/catalog-server"
  humanReadableName     = "provider-catalog-server"
  participantId         = var.provider-did
  namespace             = kubernetes_namespace.ns.metadata.0.name
  vault-url             = "http://vault:8200"
  sts-token-url         = "${module.identityhub.sts-token-url}/token"
  participant-list-file = "./assets/participants/participants.local.json"
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_catalogserver_edc"
  }
  useSVE     = var.useSVE
  depends_on = [kubernetes_job.rds-init]
  use-https  = var.use-https
}
