locals {
  roles = [
    "roles/bigquery.admin",
    "roles/dataflow.worker",
    "roles/pubsub.editor",
    "roles/storage.objectCreator"
  ]
}

resource "google_service_account" "streaming-sa" {
  depends_on = [
    google_project_service.gcp_services
  ]
  project      = local.project_id
  account_id   = "streaming-sa"
  display_name = "streaming-sa"
}

resource "google_project_iam_member" "roles" {
  depends_on = [
    google_service_account.streaming-sa
  ]
  for_each = toset(local.roles)
  project  = local.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.streaming-sa.email}"
}

resource "google_service_account" "grafana_sa" {
  depends_on = [
    google_project_service.gcp_services
  ]
  account_id   = "grafana"
  display_name = "Service Account for Grafana"
  project      = local.project_id
}

resource "google_project_iam_member" "grafana_monitoring_viewer_role_assignment" {
  depends_on = [
    google_service_account.grafana_sa
  ]
  project = local.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}

resource "google_project_iam_member" "grafana_bq_viewer_role_assignment" {
  depends_on = [
    google_service_account.grafana_sa
  ]
  project = local.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}

resource "google_project_iam_member" "grafana_bq_job_user_role_assignment" {
  depends_on = [
    google_service_account.grafana_sa
  ]
  project = local.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}

resource "google_project_iam_member" "grafana_sql_client_role_assignment" {
  depends_on = [
    google_service_account.grafana_sa
  ]
  project = local.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.grafana_sa.email}"
}