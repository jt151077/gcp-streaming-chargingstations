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


resource "google_bigquery_table" "stations-availability-raw" {
  depends_on = [
    google_bigquery_dataset.data_prod
  ]
  project             = local.project_id
  dataset_id          = google_bigquery_dataset.data_prod.dataset_id
  table_id            = "StationsAvailabilityStream"
  deletion_protection = false

  schema = <<EOF
[
  {
    "name": "data",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "The data"
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
    `proj-20220905-demo-project.data_prod.ChargingStations` ),
  status AS (
  SELECT
    SAFE.PARSE_JSON(DATA) AS json_data
  FROM
    `proj-20220905-demo-project.data_prod.RawStationsAvailability`)
SELECT
  * EXCEPT (json_data),
  JSON_VALUE(json_data.charger_total) as charger_total,
  JSON_VALUE(json_data.charger_in_use) as charger_in_use,
  JSON_VALUE(json_data.updated) as updated,
  ST_GEOGPOINT(lng, lat) AS lnglat,
  CONCAT(lat, ", ", lng) AS cslatlng
FROM
  status s1
JOIN
  stations
ON
  CAST(JSON_VALUE(json_data.station_id) AS INT64) = id
WHERE
  json_data.charger_total IS NOT NULL
  AND JSON_VALUE(json_data.updated) = (
  SELECT
    MAX(JSON_VALUE(json_data.updated))
  FROM
    status s2
  WHERE
    JSON_VALUE(s1.json_data.station_id) = JSON_VALUE(s2.json_data.station_id))
ORDER BY
  JSON_VALUE(json_data.station_id) ASC
EOF
    use_legacy_sql = false
  }
}
