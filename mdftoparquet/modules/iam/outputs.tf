output "service_account_email" {
  description = "Email of the service account created for the Cloud Function"
  value       = google_service_account.function_service_account.email
}

output "function_event_receiver_id" {
  description = "ID of the eventarc.eventReceiver permission"
  value       = google_project_iam_member.function_event_receiver.id
}

output "service_account_key" {
  description = "Service account key for local development/testing (private key in base64-encoded JSON format)"
  value       = google_service_account_key.function_sa_key.private_key
  sensitive   = true
}

output "function_service_usage_id" {
  description = "ID of the serviceusage.serviceUsageConsumer permission"
  value       = google_project_iam_member.function_service_usage.id
}
