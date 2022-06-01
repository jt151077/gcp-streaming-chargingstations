locals {
  roles = [
    "roles/bigquery.admin",
    "roles/dataflow.worker",
    "roles/pubsub.editor",
    "roles/storage.objectCreator"
  ]
}

resource "google_service_account" "streaming-sa" {
  project      = local.project_id
  account_id   = "streaming-sa"
  display_name = "streaming-sa"
}

resource "google_project_iam_member" "roles" {
  for_each = toset(local.roles)
  project  = local.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.streaming-sa.email}"
}