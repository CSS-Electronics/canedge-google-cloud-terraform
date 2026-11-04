/**
* Programmatic access (e.g. AI agents): One service account + JSON key for the whole data lake
*
* - Input bucket: read, list and create objects anywhere; delete/overwrite only .json/.dbc files in the bucket
*   root (e.g. dbc-groups.json, events.json, DBC files) and device Configuration Files (<device>/config-*.json).
*   Log files, device.json and other files stay protected (in Cloud Storage, overwriting requires delete)
* - Output bucket: full object access (e.g. remove Parquet files before a backlog re-run)
* - BigQuery: run queries (project) + read the data lake dataset (dataset only)
* - Logs: the CANedge Cloud Functions' logs only (log view + conditional view accessor)
* - The HTTP functions (map tables, backlog, aggregation) can be invoked by any authenticated account (existing
*   run.invoker bindings), so this account can run them without an extra binding
*/

locals {
  objects_prefix = "projects/_/buckets/${var.input_bucket_name}/objects/"
  log_view_id    = "canedge-${var.unique_id}"
  log_view_name  = "projects/${var.project}/locations/global/buckets/_Default/views/${local.log_view_id}"
  member         = "serviceAccount:${google_service_account.programmatic.email}"
}

resource "google_service_account" "programmatic" {
  account_id   = "${var.unique_id}-programmatic"
  display_name = "Programmatic access (e.g. AI agents)"
  description  = "CANedge data lake: buckets, BigQuery, function logs (key: <id>-programmatic-access-account.json)"
}

resource "google_service_account_key" "programmatic_key" {
  service_account_id = google_service_account.programmatic.name
}

# ---------------------------------------------------------------- input bucket
resource "google_storage_bucket_iam_member" "input_viewer" {
  bucket = var.input_bucket_name
  role   = "roles/storage.objectViewer"
  member = local.member
}

resource "google_storage_bucket_iam_member" "input_creator" {
  bucket = var.input_bucket_name
  role   = "roles/storage.objectCreator"
  member = local.member
}

# extract() returns "" if the template does not match: "{folder}/" matches any object in a folder
resource "google_storage_bucket_iam_member" "input_limited_delete" {
  bucket = var.input_bucket_name
  role   = "roles/storage.objectUser"
  member = local.member
  condition {
    title       = "root-json-dbc-and-device-configs"
    description = "Delete/overwrite root .json/.dbc files and <device>/config-*.json only"
    expression  = <<-EOT
      resource.type == "storage.googleapis.com/Object" && resource.name.startsWith("${local.objects_prefix}") && (
        (resource.name.extract("${local.objects_prefix}{folder}/") == "" &&
          (resource.name.endsWith(".json") || resource.name.endsWith(".dbc"))) ||
        (resource.name.extract("${local.objects_prefix}{device}/config-") != "" && resource.name.endsWith(".json")))
    EOT
  }
}

# ---------------------------------------------------------------- output bucket
resource "google_storage_bucket_iam_member" "output_admin" {
  bucket = var.output_bucket_name
  role   = "roles/storage.objectAdmin"
  member = local.member
}

# ---------------------------------------------------------------- BigQuery
resource "google_project_iam_member" "bigquery_job_user" {
  project = var.project
  role    = "roles/bigquery.jobUser"
  member  = local.member
}

resource "google_bigquery_dataset_iam_member" "dataset_viewer" {
  project    = var.project
  dataset_id = var.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = local.member
}

# ---------------------------------------------------------------- logs of the CANedge Cloud Functions only
resource "google_logging_log_view" "canedge_functions" {
  name        = local.log_view_id
  bucket      = "projects/${var.project}/locations/global/buckets/_Default"
  description = "Logs of the CANedge Cloud Functions (${var.unique_id})"
  filter      = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name =~ \"^${var.unique_id}-(mdf-to-parquet|mdf-to-parquet-backlog|aggregation|bq-map-tables)$\""
}

resource "google_project_iam_member" "log_view_accessor" {
  project = var.project
  role    = "roles/logging.viewAccessor"
  member  = local.member
  condition {
    title       = "canedge-function-logs-only"
    description = "Only the log view ${local.log_view_id}"
    expression  = "resource.name == \"${local.log_view_name}\""
  }
  depends_on = [google_logging_log_view.canedge_functions]
}
