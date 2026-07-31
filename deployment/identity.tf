module "vault" {
  source            = "./modules/vault"
  humanReadableName = "vault"
  namespace         = kubernetes_namespace.ns.metadata.0.name
}

module "identityhub" {
  depends_on        = [module.vault, kubernetes_job.rds-init]
  source            = "./modules/identity-hub"
  humanReadableName = "identityhub"
  participantId     = "did:web:identityhub"
  vault-url         = "http://vault:8200"
  service-name      = "identityhub"
  database = {
    user     = var.rds-master-user
    password = var.rds-master-password
    url      = "jdbc:postgresql://${var.rds-host}:${var.rds-port}/cssp_identity_edc"
  }
  namespace      = kubernetes_namespace.ns.metadata.0.name
  useSVE         = var.useSVE
  node-port-base = 32000
  use-https      = var.use-https
}
