locals {
  roles = [
    "roles/bigquery.metadataViewer",
    "roles/bigquery.dataEditor"
  ]
}

resource "google_project_iam_member" "pub-sub-role" {
  depends_on = [
    google_project_service.gcp_services
  ]
  for_each = toset(local.roles)
  project  = local.project_id
  role     = each.value
  member   = "serviceAccount:service-${local.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
