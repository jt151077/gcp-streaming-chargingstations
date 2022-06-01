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


resource "google_storage_bucket" "source_csv" {
  project       = local.project_id
  name          = "${local.project_id}_source_csv"
  storage_class = "REGIONAL"
  location      = local.project_default_region
}

resource "google_storage_bucket_object" "charging_stations" {
  name   = "stations.csv"
  source = "stations.csv"
  bucket = google_storage_bucket.source_csv.name
}