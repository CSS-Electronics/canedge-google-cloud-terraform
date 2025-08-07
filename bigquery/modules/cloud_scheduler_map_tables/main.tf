/**
* Module to deploy Google Cloud Scheduler for the BigQuery Map Tables Cloud Function
* This creates a scheduler job that is deployed in a paused state
*/

resource "google_cloud_scheduler_job" "map_tables_scheduler" {
  name             = "${var.unique_id}-map-tables-scheduler"
  project          = var.project
  region           = var.region
  description      = "Trigger for CANedge BigQuery table mapping function (daily schedule if enabled)"
  schedule         = var.schedule
  time_zone        = var.time_zone
  attempt_deadline = "1800s"  # 30 minutes
  
  # Set to PAUSED initially, can be changed to ENABLED in the GCP console
  paused           = true
  
  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-${var.project}.cloudfunctions.net/${var.unique_id}-bg-map-tables"
    
    # Use OIDC token for Cloud Function authorization
    oidc_token {
      service_account_email = var.service_account_email
      audience              = "https://${var.region}-${var.project}.cloudfunctions.net/${var.unique_id}-bg-map-tables"
    }
  }
  
  # Important: Make sure the function is fully deployed before setting up the scheduler
  depends_on = [
    var.cloud_function_id
  ]
}
