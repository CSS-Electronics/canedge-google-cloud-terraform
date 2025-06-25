variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for function deployment"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier to namespace resources"
  type        = string
}

variable "input_bucket_name" {
  description = "Name of the existing input bucket"
  type        = string
}

variable "output_bucket_name" {
  description = "Name of the output bucket"
  type        = string
}

variable "service_account_email" {
  description = "Email of the service account to use for the Cloud Function"
  type        = string
}

variable "iam_dependencies" {
  description = "List of IAM resources that the function depends on to ensure permissions are ready"
  type        = list(any)
  default     = []
}


variable "function_zip" {
  description = "Filename of the Cloud Function ZIP file in the input bucket (e.g. mdf-to-parquet-google-function-vX.X.X.zip)"
  type        = string
}
