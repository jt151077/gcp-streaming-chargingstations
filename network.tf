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
