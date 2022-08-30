resource "google_service_account" "grafana_sa" {
  account_id   = "grafana"
  display_name = "Service Account for Grafana"
  project      = local.project_id
}

resource "google_project_iam_member" "grafana_monitoring_viewer_role_assignment" {
  project = local.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}

resource "google_project_iam_member" "grafana_bq_viewer_role_assignment" {
  project = local.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}

resource "google_project_iam_member" "grafana_bq_job_user_role_assignment" {
  project = local.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}

resource "google_cloud_run_service" "default" {
  provider = google-beta
  name     = "grafana"
  location = local.project_default_region
  project  = local.project_id

  metadata {
    annotations = {
      "run.googleapis.com/ingress" : "internal-and-cloud-load-balancing"
    }
  }

  template {
    spec {
      service_account_name = google_service_account.grafana_sa.email
      containers {
        image = "mirror.gcr.io/grafana/grafana:${var.grafana_version}"
        ports {
          name           = "http1"
          container_port = 8080
        }
        dynamic "env" {
          for_each = local.static_envs
          content {
            name  = env.key
            value = env.value
          }
        }
        env {
          name = "GF_DATABASE_PASSWORD"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.secret.secret_id
              key  = "latest"
            }
          }
        }
        volume_mounts {
          name       = "datasource-volume"
          mount_path = "/etc/grafana/provisioning/datasources"
        }
        volume_mounts {
          name       = "dashboard-yaml-volume"
          mount_path = "/etc/grafana/provisioning/dashboards"
        }
        volume_mounts {
          name       = "dashboard-json-volume"
          mount_path = "/var/lib/grafana/dashboards/gcp"
        }
      }
      volumes {
        name = "datasource-volume-1"
        secret {
          secret_name = google_secret_manager_secret.datasource.secret_id
          items {
            key  = "latest"
            path = "cloud-monitoring.yaml"
          }
        }
      }
      volumes {
        name = "datasource-volume"
        secret {
          secret_name = google_secret_manager_secret.datasource.secret_id
          items {
            key  = "latest"
            path = "grafana-bigquery.yaml"
          }
        }
      }
      volumes {
        name = "dashboard-yaml-volume"
        secret {
          secret_name = google_secret_manager_secret.dashboard-yaml.secret_id
          items {
            key  = "latest"
            path = "gclb.yaml"
          }
        }
      }
      volumes {
        name = "dashboard-json-volume"
        secret {
          secret_name = google_secret_manager_secret.dashboard-json.secret_id
          items {
            key  = "latest"
            path = "gclb.json"
          }
        }
      }
      volumes {
        name = "dashboard-json-volume-1"
        secret {
          secret_name = google_secret_manager_secret.dashboard-json.secret_id
          items {
            key  = "latest"
            path = "gcst.json"
          }
        }
      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "100"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.instance.connection_name
        "run.googleapis.com/client-name"        = "grafana"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.gcp_services,
    google_sql_database.database,
    google_sql_user.user,
    google_secret_manager_secret_iam_member.datasource-access,
    google_secret_manager_secret_iam_member.secret-access,
    google_secret_manager_secret_iam_member.dashboard-yaml-access,
    google_secret_manager_secret_iam_member.dashboard-json-access,
  ]
}

locals {
  static_envs = {
    GF_LOG_LEVEL                  = "DEBUG"
    GF_SERVER_ROOT_URL            = "https://${var.domain}"
    GF_SERVER_HTTP_PORT           = "8080"
    GF_DATABASE_TYPE              = "mysql"
    GF_DATABASE_HOST              = "/cloudsql/${google_sql_database_instance.instance.connection_name}"
    GF_DATABASE_USER              = google_sql_user.user.name
    GF_DATABASE_NAME              = google_sql_database.database.name
    GF_AUTH_JWT_ENABLED           = "true"
    GF_AUTH_JWT_HEADER_NAME       = "X-Goog-Iap-Jwt-Assertion"
    GF_AUTH_JWT_USERNAME_CLAIM    = "email"
    GF_AUTH_JWT_EMAIL_CLAIM       = "email"
    GF_AUTH_JWT_JWK_SET_URL       = "https://www.gstatic.com/iap/verify/public_key-jwk"
    GF_AUTH_JWT_EXPECTED_CLAIMS   = "{\"iss\": \"https://cloud.google.com/iap\"}"
    GF_AUTH_PROXY_ENABLED         = "true"
    GF_AUTH_PROXY_HEADER_NAME     = "X-Goog-Authenticated-User-Email"
    GF_AUTH_PROXY_HEADER_PROPERTY = "email"
    GF_AUTH_PROXY_AUTO_SIGN_UP    = "true"
    GF_USERS_AUTO_ASSIGN_ORG_ROLE = "Viewer"
    GF_USERS_VIEWERS_CAN_EDIT     = "true"
    GF_USERS_EDITORS_CAN_ADMIN    = "false"
    GF_INSTALL_PLUGINS            = "grafana-bigquery-datasource"
  }
}

resource "google_secret_manager_secret" "datasource" {
  project   = local.project_id
  secret_id = "datasource-yml"
  replication {
    automatic = true
  }

  depends_on = [
    google_project_service.gcp_services
  ]
}

resource "google_secret_manager_secret_version" "datasource-version-data" {
  secret      = google_secret_manager_secret.datasource.name
  secret_data = file("${path.module}/provisioning/datasources/cloud-monitoring.yaml")
}

resource "google_secret_manager_secret_iam_member" "datasource-access" {
  project    = local.project_id
  secret_id  = google_secret_manager_secret.datasource.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.grafana_sa.email}"
  depends_on = [
    google_secret_manager_secret.datasource, 
    google_secret_manager_secret_version.datasource-version-data
  ]
}

resource "google_secret_manager_secret_version" "datasource-version-data-1" {
  secret      = google_secret_manager_secret.datasource.name
  secret_data = file("${path.module}/provisioning/datasources/grafana-bigquery.yaml")
}

resource "google_secret_manager_secret_iam_member" "datasource-access-1" {
  project    = local.project_id
  secret_id  = google_secret_manager_secret.datasource.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.grafana_sa.email}"
  depends_on = [
    google_secret_manager_secret.datasource, 
    google_secret_manager_secret_version.datasource-version-data-1
  ]
}


resource "google_secret_manager_secret" "dashboard-yaml" {
  project   = local.project_id
  secret_id = "dashboard-yaml"
  replication {
    automatic = true
  }

  depends_on = [
    google_project_service.gcp_services
  ]
}

resource "google_secret_manager_secret_version" "dashboard-yaml-version-data" {
  secret      = google_secret_manager_secret.dashboard-yaml.name
  secret_data = file("${path.module}/provisioning/dashboards/gclb.yaml")
}

resource "google_secret_manager_secret_iam_member" "dashboard-yaml-access" {
  project    = local.project_id
  secret_id  = google_secret_manager_secret.dashboard-yaml.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.grafana_sa.email}"
  depends_on = [
    google_secret_manager_secret.dashboard-yaml, 
    google_secret_manager_secret_version.dashboard-yaml-version-data
  ]
}


resource "google_secret_manager_secret" "dashboard-json" {
  project   = local.project_id
  secret_id = "dashboard-json"
  replication {
    automatic = true
  }

  depends_on = [
    google_project_service.gcp_services
  ]
}

resource "google_secret_manager_secret_version" "dashboard-json-version-data" {
  secret      = google_secret_manager_secret.dashboard-json.name
  secret_data = file("${path.module}/provisioning/dashboards/gclb.json")
}

resource "google_secret_manager_secret_iam_member" "dashboard-json-access" {
  project    = local.project_id
  secret_id  = google_secret_manager_secret.dashboard-json.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.grafana_sa.email}"
  depends_on = [
    google_secret_manager_secret.dashboard-json,
    google_secret_manager_secret_version.dashboard-json-version-data
  ]
}

resource "google_secret_manager_secret_version" "dashboard-json-version-data-1" {
  secret      = google_secret_manager_secret.dashboard-json.name
  secret_data = file("${path.module}/provisioning/dashboards/gcst.json")
}

resource "google_secret_manager_secret_iam_member" "dashboard-json-access-1" {
  project    = local.project_id
  secret_id  = google_secret_manager_secret.dashboard-json.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.grafana_sa.email}"
  depends_on = [
    google_secret_manager_secret.dashboard-json,
    google_secret_manager_secret_version.dashboard-json-version-data-1
  ]
}

resource "google_service_account" "grafana_bq" {
  account_id   = "grafana-bq"
  display_name = "Service Account for Grafana BigQuery"
  project      = local.project_id
}

/*
resource "google_project_iam_member" "grafana_bq_viewer_role_assignment" {
  project = local.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.grafana_bq.email}"
}

resource "google_project_iam_member" "grafana_bq_job_user_role_assignment" {
  project = local.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.grafana_bq.email}"
}*/