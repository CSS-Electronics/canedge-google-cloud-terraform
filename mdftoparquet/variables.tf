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
