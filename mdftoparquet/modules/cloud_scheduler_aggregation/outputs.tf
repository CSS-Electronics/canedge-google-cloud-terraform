output "scheduler_job_name" {
  description = "Name of the created Cloud Scheduler job"
  value       = google_cloud_scheduler_job.aggregation_scheduler.name
}

output "scheduler_job_id" {
  description = "ID of the created Cloud Scheduler job"
  value       = google_cloud_scheduler_job.aggregation_scheduler.id
}

output "scheduler_state" {
  description = "Current state of the Cloud Scheduler job (ENABLED or PAUSED)"
  value       = google_cloud_scheduler_job.aggregation_scheduler.paused ? "PAUSED" : "ENABLED"
}
