/**
* Outputs for the Monitoring Module
*/

output "metric_id" {
  description = "ID of the logging metric for monitoring 'NEW EVENT' occurrences"
  value       = google_logging_metric.mdf_to_parquet_event_metric.id
}

output "metric_name" {
  description = "Name of the logging metric for monitoring 'NEW EVENT' occurrences"
  value       = google_logging_metric.mdf_to_parquet_event_metric.name
}

output "alert_policy_id" {
  description = "ID of the alert policy for 'NEW EVENT' notifications"
  value       = google_monitoring_alert_policy.mdf_to_parquet_event_alert.id
}

output "notification_channel_id" {
  description = "ID of the email notification channel for alerts"
  value       = google_monitoring_notification_channel.email_channel.id
}
