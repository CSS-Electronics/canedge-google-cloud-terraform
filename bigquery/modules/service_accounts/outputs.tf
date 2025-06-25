output "bigquery_admin_service_account_email" {
  description = "Email address of the BigQuery Admin service account"
  value       = google_service_account.bigquery_admin.email
}

output "bigquery_user_service_account_email" {
  description = "Email address of the BigQuery User service account"
  value       = google_service_account.bigquery_user.email
}

output "bigquery_admin_key" {
  description = "Service account key for BigQuery Admin in base64-encoded format"
  value       = google_service_account_key.bigquery_admin_key.private_key
  sensitive   = true
}

output "bigquery_user_key" {
  description = "Service account key for BigQuery User in base64-encoded format"
  value       = google_service_account_key.bigquery_user_key.private_key
  sensitive   = true
}
