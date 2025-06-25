# BigQuery Admin Service Account
resource "google_service_account" "bigquery_admin" {
  account_id   = "${var.unique_id}-bigquery-admin"
  display_name = "BigQuery Admin Service Account"
  description  = "Service account with BigQuery Admin and Storage Admin roles for managing tables"
}

# BigQuery User Service Account
resource "google_service_account" "bigquery_user" {
  account_id   = "${var.unique_id}-bigquery-user"
  display_name = "BigQuery User Service Account"
  description  = "Service account with BigQuery Data Viewer and Storage Object Viewer roles for querying data"
}

# BigQuery Admin Permissions
resource "google_project_iam_member" "bigquery_admin_role" {
  project = var.project
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_service_account.bigquery_admin.email}"
}

resource "google_project_iam_member" "storage_admin_role" {
  project = var.project
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.bigquery_admin.email}"
}

# BigQuery User Permissions
resource "google_project_iam_member" "bigquery_data_viewer_role" {
  project = var.project
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.bigquery_user.email}"
}

resource "google_project_iam_member" "bigquery_job_user_role" {
  project = var.project
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.bigquery_user.email}"
}

resource "google_project_iam_member" "storage_object_viewer_role" {
  project = var.project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.bigquery_user.email}"
}

# Create service account keys
resource "google_service_account_key" "bigquery_admin_key" {
  service_account_id = google_service_account.bigquery_admin.name
}

resource "google_service_account_key" "bigquery_user_key" {
  service_account_id = google_service_account.bigquery_user.name
}
