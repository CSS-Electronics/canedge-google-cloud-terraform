/**
* Input variables for the CANedge GCP Terraform Stack
*/

variable "project" {
  description = "GCP Project ID where resources will be deployed"
  type        = string
}

variable "region" {
  description = "GCP region for resource deployment (e.g., europe-west4)"
  type        = string
}

variable "input_bucket_name" {
  description = "Name of the existing GCS bucket containing MDF4 files"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier to namespace resources"
  type        = string
  default     = "canedge"
}

variable "notification_email" {
  description = "Email address to receive notifications from the Cloud Function"
  type        = string
}

variable "function_zip" {
  description = "Filename of the Cloud Function ZIP file in the input bucket (e.g. mdf-to-parquet-google-function-vX.X.X.zip)"
  type        = string
}

variable "function_zip_backlog" {
  description = "Filename of the Backlog Cloud Function ZIP file in the input bucket (e.g. backlog-processor-google-vX.X.X.zip)"
  type        = string
}

variable "function_zip_aggregation" {
  description = "Filename of the Aggregation Cloud Function ZIP file in the input bucket (e.g. aggregation-processor-google-vX.X.X.zip)"
  type        = string
}

variable "scheduler_cron" {
  description = "Cron schedule expression for the Aggregation Cloud Function scheduler job"
  type        = string
  default     = "0 0 * * *"  # Default to midnight every day
}

variable "scheduler_timezone" {
  description = "Time zone for the scheduler job"
  type        = string
  default     = "Etc/UTC"
}
