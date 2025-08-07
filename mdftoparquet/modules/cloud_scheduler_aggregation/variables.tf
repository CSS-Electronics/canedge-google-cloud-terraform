variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for scheduler deployment"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier to namespace resources"
  type        = string
}

variable "service_account_email" {
  description = "Email of the service account to use for the scheduler job"
  type        = string
}

variable "cloud_function_id" {
  description = "ID of the Cloud Function to be triggered"
  type        = string
}

variable "schedule" {
  description = "Cron schedule expression for the job"
  type        = string
  default     = "0 0 * * *"  # Default to midnight every day
}

variable "time_zone" {
  description = "Time zone for the scheduler job"
  type        = string
  default     = "Etc/UTC"
}
