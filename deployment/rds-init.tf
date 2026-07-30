resource "kubernetes_config_map" "rds-init-sql" {
  metadata {
    name      = "rds-init-sql"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }
  data = {
    "init.sql" = <<-EOT
      SELECT 'CREATE DATABASE cssp_consumer_edc' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cssp_consumer_edc')\gexec
      SELECT 'CREATE DATABASE cssp_provider_edc' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cssp_provider_edc')\gexec
      SELECT 'CREATE DATABASE cssp_identity_edc' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cssp_identity_edc')\gexec
      SELECT 'CREATE DATABASE cssp_catalogserver_edc' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cssp_catalogserver_edc')\gexec
      SELECT 'CREATE DATABASE cssp_issuer_edc' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cssp_issuer_edc')\gexec
    EOT

    "issuer-init.sql" = <<-EOT
      CREATE TABLE IF NOT EXISTS membership_attestations (
          membership_type       integer   DEFAULT 0,
          holder_id             varchar   NOT NULL,
          membership_start_date timestamp DEFAULT now() NOT NULL,
          id                    varchar   DEFAULT gen_random_uuid() NOT NULL
              CONSTRAINT attestations_pk PRIMARY KEY
      );

      CREATE UNIQUE INDEX IF NOT EXISTS membership_attestation_holder_id_uindex
          ON membership_attestations (holder_id);

      INSERT INTO membership_attestations (membership_type, holder_id)
          VALUES (1, '${var.consumer-did}')
          ON CONFLICT DO NOTHING;
      INSERT INTO membership_attestations (membership_type, holder_id)
          VALUES (2, '${var.provider-did}')
          ON CONFLICT DO NOTHING;
    EOT
  }
}

resource "kubernetes_job" "rds-init" {
  metadata {
    name      = "rds-init"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }

  spec {
    backoff_limit              = 3
    ttl_seconds_after_finished = 60

    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "init-databases"
          image = "postgres:16.3-alpine3.20"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
              PGPASSWORD=$RDS_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $RDS_USER -f /sql/init.sql
              PGPASSWORD=$RDS_PASSWORD psql -h $RDS_HOST -p $RDS_PORT -U $RDS_USER -d cssp_issuer_edc -f /sql/issuer-init.sql
            EOT
          ]

          env {
            name  = "RDS_HOST"
            value = var.rds-host
          }
          env {
            name  = "RDS_PORT"
            value = var.rds-port
          }
          env {
            name  = "RDS_USER"
            value = var.rds-master-user
          }
          env {
            name = "RDS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.rds-credentials.metadata.0.name
                key  = "password"
              }
            }
          }

          volume_mount {
            name       = "sql"
            mount_path = "/sql"
          }
        }

        volume {
          name = "sql"
          config_map {
            name = kubernetes_config_map.rds-init-sql.metadata.0.name
          }
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "2m"
  }
}

resource "kubernetes_secret" "rds-credentials" {
  metadata {
    name      = "rds-credentials"
    namespace = kubernetes_namespace.ns.metadata.0.name
  }
  data = {
    password = var.rds-master-password
  }
}
