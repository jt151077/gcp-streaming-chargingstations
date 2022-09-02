/**
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


resource "google_storage_bucket" "dataflow-tmp-bucket" {
  depends_on = [
    google_project_service.gcp_services
  ]
  project       = local.project_id
  name          = "${local.project_id}-dataflow-tmp-bucket"
  storage_class = "REGIONAL"
  location      = local.project_default_region
  force_destroy = true
}

resource "google_dataflow_job" "dataflow-job" {
  depends_on = [
    google_storage_bucket.dataflow-tmp-bucket,
    google_pubsub_topic.ingestion-topic,
    google_project_iam_member.roles,
    google_compute_subnetwork.custom-subnet
  ]

  project           = local.project_id
  region            = local.project_default_region
  name              = "${local.project_id}-${google_pubsub_topic.ingestion-topic.name}"
  network           = google_compute_network.custom_vpc.id
  subnetwork        = "regions/${local.project_default_region}/subnetworks/${google_compute_subnetwork.custom-subnet.name}"
  on_delete         = "cancel"
  template_gcs_path = "gs://dataflow-templates-europe-west1/latest/PubSub_to_BigQuery"
  temp_gcs_location = "${google_storage_bucket.dataflow-tmp-bucket.url}/messages"
  parameters = {
    inputTopic      = google_pubsub_topic.ingestion-topic.id
    outputTableSpec = "${local.project_id}:${google_bigquery_dataset.data_prod.dataset_id}.${google_bigquery_table.stations-availability.table_id}"
  }
  service_account_email = google_service_account.streaming-sa.email
}

resource "google_pubsub_topic" "ingestion-topic" {
  depends_on = [
    google_compute_network.custom_vpc
  ]
  project = local.project_id
  name    = var.topic_id
}