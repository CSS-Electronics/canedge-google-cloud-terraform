/**
* Module to deploy the Aggregation Cloud Function
*/

# This forces Terraform to check the hash of the ZIP file at every apply
# and redeploy the function if the file has changed
data "external" "function_zip_hash" {
  program = ["bash", "-c", "echo '{\"result\":\"'$(gsutil hash gs://${var.input_bucket_name}/${var.function_zip_aggregation} | grep md5 | awk '{print $3}')'\"}'"]
}

resource "google_cloudfunctions2_function" "aggregation_function" {
  name        = "${var.unique_id}-aggregation"
  project     = var.project
  location    = var.region
  description = "CANedge data lake aggregation function - Hash: ${data.external.function_zip_hash.result.result}"
  
  build_config {
    runtime     = "python311"
    entry_point = "process_mdf_file"
    source {
      storage_source {
        bucket = var.input_bucket_name
        object = var.function_zip_aggregation
      }
    }
  }

  service_config {
    available_memory       = "1Gi"
    timeout_seconds        = 3600
    max_instance_count     = 1  # Limit to one instance to avoid race conditions
    environment_variables  = {
      INPUT_BUCKET    = var.input_bucket_name
    }
    service_account_email  = var.service_account_email
  }
  
  labels = {
    goog-terraform-provisioned = "true"
  }
}

# IAM binding for Cloud Functions v2 using the gcloud-based approach
# This uses the underlying Cloud Run service directly with the correct service name format

# Get the underlying Cloud Run service name directly from the function's output
# This is the reliable way to connect IAM permissions to Cloud Functions v2
resource "google_cloud_run_service_iam_member" "member" {
  project  = var.project
  location = var.region
  service  = google_cloudfunctions2_function.aggregation_function.name
  role     = "roles/run.invoker"
  member   = "allAuthenticatedUsers"
  
  # Important: Make sure the function is fully deployed before setting IAM
  depends_on = [
    google_cloudfunctions2_function.aggregation_function
  ]
}
