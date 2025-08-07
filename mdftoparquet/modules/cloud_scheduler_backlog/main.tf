/**
* Module to deploy Google Cloud Scheduler for the backlog Cloud Function
* This creates a scheduler job that is enabled for manual triggering only
*/

resource "google_cloud_scheduler_job" "backlog_scheduler" {
  name             = "${var.unique_id}-mdf-to-parquet-backlog-scheduler"
  project          = var.project
  region           = var.region
  description      = "Manual trigger for CANedge data lake backlog function"
  # Use a schedule that will never naturally occur (Feb 31, which doesn't exist)
  schedule         = "0 0 31 2 *"
  time_zone        = var.time_zone
  attempt_deadline = "1800s"  # 30 minutes
  
  # Set to ENABLED so it can be manually triggered
  paused           = false
  
  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-${var.project}.cloudfunctions.net/${var.unique_id}-mdf-to-parquet-backlog"
    
    # Use OIDC token for Cloud Function authorization
    oidc_token {
      service_account_email = var.service_account_email
      audience              = "https://${var.region}-${var.project}.cloudfunctions.net/${var.unique_id}-mdf-to-parquet-backlog"
    }
  }
  
  # Important: Make sure the function is fully deployed before setting up the scheduler
  depends_on = [
    var.cloud_function_id
  ]
}
