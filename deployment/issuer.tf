module "dataspace-issuer" {
  count             = var.enable-issuer ? 1 : 0
  source            = "./modules/issuer"
  humanReadableName = "dataspace-issuer-service"
  participantId     = var.issuer-did
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_issuer_edc"
  }
  vault-url  = "http://provider-vault:8200"
  namespace  = kubernetes_namespace.ns.metadata.0.name
  useSVE     = var.useSVE
  depends_on = [module.provider-vault, kubernetes_job.rds-init]
  use-https  = var.use-https
}
