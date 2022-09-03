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

resource "google_compute_network" "custom_vpc" {
  depends_on = [
    google_project_service.gcp_services
  ]
  name                    = "custom-vpc"
  project                 = local.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "custom-subnet" {
  depends_on = [
    google_compute_network.custom_vpc
  ]
  name          = "subnet-${local.project_default_region}"
  project       = local.project_id
  ip_cidr_range = "10.0.1.0/29"
  region        = local.project_default_region
  network       = google_compute_network.custom_vpc.id
}


resource "google_compute_security_policy" "api-policy" {
  provider = google-beta
  name     = "api-policy"
  project  = local.project_id

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}

resource "google_iap_brand" "project_brand" {
  support_email     = local.iap_brand_support_email
  application_title = "Cloud IAP protected Application"
  project           = local.project_id
}

resource "google_iap_client" "project_client" {
  depends_on = [
    google_project_service.gcp_services,
    google_iap_brand.project_brand
  ]
  display_name = "LB Client"
  brand        = google_iap_brand.project_brand.name
}

resource "google_iap_web_backend_service_iam_binding" "binding" {
  depends_on = [
    google_project_service.gcp_services,
    module.lb-http
  ]
  project             = local.project_id
  web_backend_service = "tf-cr-lb-backend-default"
  role                = "roles/iap.httpsResourceAccessor"
  members = [
    "user:${local.iap_brand_support_email}",
  ]
}

resource "google_compute_region_network_endpoint_group" "cloud_run_neg" {
  depends_on = [
    google_project_service.gcp_services,
    google_cloud_run_service.grafana
  ]

  name                  = "cloud-run-neg"
  network_endpoint_type = "SERVERLESS"
  region                = local.project_default_region
  project               = local.project_id
  cloud_run {
    service = google_cloud_run_service.grafana.name
  }
}

module "lb-http" {
  depends_on = [
    google_project_service.gcp_services,
    google_cloud_run_service.grafana,
    google_compute_region_network_endpoint_group.cloud_run_neg,
    google_iap_client.project_client,
    google_compute_security_policy.api-policy
  ]

  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 5.1"
  name    = "tf-cr-lb"
  project = local.project_id

  ssl                             = true
  managed_ssl_certificate_domains = [var.domain]
  https_redirect                  = true

  backends = {
    default = {
      description = null
      groups = [
        {
          group = google_compute_region_network_endpoint_group.cloud_run_neg.id
        }
      ]
      enable_cdn              = false
      security_policy         = google_compute_security_policy.api-policy.id
      custom_request_headers  = null
      custom_response_headers = null

      iap_config = {
        enable               = true
        oauth2_client_id     = google_iap_client.project_client.client_id
        oauth2_client_secret = google_iap_client.project_client.secret
      }
      log_config = {
        enable      = false
        sample_rate = null
      }
    }
  }
}

output "external_ip" {
  value = module.lb-http.external_ip
}