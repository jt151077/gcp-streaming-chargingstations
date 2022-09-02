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

resource "google_bigquery_dataset" "data_prod" {
  depends_on = [
    google_project_service.gcp_services
  ]
  project       = local.project_id
  dataset_id    = "data_prod"
  friendly_name = "data_prod"
  location      = local.project_default_region
}

resource "google_bigquery_dataset" "data_raw" {
  depends_on = [
    google_project_service.gcp_services
  ]
  project       = local.project_id
  dataset_id    = "data_raw"
  friendly_name = "data_raw"
  location      = local.project_default_region
}

resource "google_bigquery_table" "charging-stations" {
  depends_on = [
    google_bigquery_dataset.data_prod
  ]
  project             = local.project_id
  dataset_id          = google_bigquery_dataset.data_prod.dataset_id
  table_id            = "ChargingStations"
  deletion_protection = false

  schema = <<EOF
[
  {
    "description": "",
    "type": "INTEGER",
    "name": "id",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "STRING",
    "name": "name",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "STRING",
    "name": "street",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "STRING",
    "name": "city",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "FLOAT64",
    "name": "lat",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "FLOAT64",
    "name": "lng",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "STRING",
    "name": "provider",
    "mode": "NULLABLE"
  }
]
EOF
}


resource "google_bigquery_table" "stations-availability" {
  depends_on = [
    google_bigquery_dataset.data_prod
  ]
  project             = local.project_id
  dataset_id          = google_bigquery_dataset.data_prod.dataset_id
  table_id            = "StationsAvailability"
  deletion_protection = false

  schema = <<EOF
[
  {
    "description": "",
    "type": "INTEGER",
    "name": "station_id",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "INTEGER",
    "name": "charger_in_use",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "INTEGER",
    "name": "charger_total",
    "mode": "NULLABLE"
  },
  {
    "description": "",
    "type": "DATETIME",
    "name": "updated",
    "mode": "NULLABLE"
  }
]
EOF
}


resource "google_bigquery_table" "items_per_session_cluster" {

  depends_on = [
    google_bigquery_dataset.data_prod,
    google_bigquery_table.stations-availability,
    google_bigquery_table.charging-stations
  ]

  project             = local.project_id
  dataset_id          = google_bigquery_dataset.data_prod.dataset_id
  table_id            = "ChargersAvailability"
  deletion_protection = false

  view {
    query          = <<EOF
WITH
  stations AS (
  SELECT
    *
  FROM
    `PROJECT_ID.data_prod.ChargingStations` )
SELECT
  *,
  ST_GEOGPOINT(lng,
    lat) AS lnglat,
  CONCAT(lat, ", ", lng) AS cslatlng
FROM
  `PROJECT_ID.data_prod.StationsAvailability` s1
JOIN
  stations
ON
  station_id = id
WHERE
  charger_total IS NOT NULL
  AND updated = (
  SELECT
    MAX(updated)
  FROM
    `PROJECT_ID.data_prod.StationsAvailability` s2
  WHERE
    s1.station_id = s2.station_id)
ORDER BY
  station_id ASC
EOF
    use_legacy_sql = false
  }
}
