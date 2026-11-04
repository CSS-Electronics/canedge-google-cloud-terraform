output "service_account_email" {
  description = "Email address of the programmatic access service account"
  value       = google_service_account.programmatic.email
}

output "key" {
  description = "Service account key for programmatic access in base64-encoded format"
  value       = google_service_account_key.programmatic_key.private_key
  sensitive   = true
}

output "log_view" {
  description = "Log view with the CANedge Cloud Functions' logs"
  value       = google_logging_log_view.canedge_functions.id
}
