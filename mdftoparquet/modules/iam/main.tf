/**
* IAM module for creating service accounts and permissions
*/

# Get the GCS service account - needed for Eventarc triggers with GCS
data "google_storage_project_service_account" "gcs_account" {
  project = var.project
}

# Create service account for the Cloud Function
resource "google_service_account" "function_service_account" {
  account_id   = "${var.unique_id}-function-sa"
  display_name = "CANedge Processor Function Service Account"
  description  = "Service account for the MDF4-to-Parquet Cloud Function"
}

# Grant the service account access to the input bucket
resource "google_storage_bucket_iam_member" "function_input_bucket_access" {
  bucket = var.input_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Grant the service account access to create objects in the output bucket
resource "google_storage_bucket_iam_member" "function_output_bucket_access" {
  bucket = var.output_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Grant additional roles for logging
resource "google_project_iam_member" "function_logging" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Required for Cloud Functions 2nd gen with GCS triggers
# Allow the GCS service account to publish to Pub/Sub
resource "google_project_iam_member" "gcs_pubsub_publishing" {
  project = var.project
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

# Allow function service account to be invoked by the Cloud Run service
resource "google_project_iam_member" "function_invoker" {
  project = var.project
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Create a service account key for local development/testing
resource "google_service_account_key" "function_sa_key" {
  service_account_id = google_service_account.function_service_account.name
}

# Grant permissions for Eventarc
# The service account needs both eventarc.eventReceiver role and serviceusage.serviceUsageConsumer
resource "google_project_iam_member" "function_event_receiver" {
  project = var.project
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}

# This role contains the eventarc.events.receiveEvent permission
resource "google_project_iam_member" "function_service_usage" {
  project = var.project
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Allow function service account to access Artifact Registry
resource "google_project_iam_member" "function_artifact_reader" {
  project = var.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}

# Allow the function service account to publish to Pub/Sub topics
resource "google_project_iam_member" "function_pubsub_publisher" {
  project = var.project
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.function_service_account.email}"
}
