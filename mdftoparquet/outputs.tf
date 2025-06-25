/**
* Outputs for the CANedge GCP Terraform Stack
*/

output "output_bucket_name" {
  description = "Name of the created output bucket for Parquet files"
  value       = module.output_bucket.output_bucket_name
}

output "cloud_function_name" {
  description = "Name of the deployed Cloud Function"
  value       = module.cloud_function.function_name
}

output "service_account_email" {
  description = "Service account email used by the Cloud Function"
  value       = module.iam.service_account_email
}

output "service_account_key" {
  description = "Service account key for local development (base64-encoded JSON)"
  value       = module.iam.service_account_key
  sensitive   = true
}


output "logging_metric_id" {
  description = "ID of the logging metric for monitoring 'NEW EVENT' occurrences"
  value       = module.monitoring.metric_id
}

output "alert_policy_id" {
  description = "ID of the alert policy for 'NEW EVENT' notifications"
  value       = module.monitoring.alert_policy_id
}
