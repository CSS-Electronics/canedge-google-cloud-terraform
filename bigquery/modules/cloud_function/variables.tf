/**
* Variables for the BigQuery table mapping Cloud Function
*/

variable "project" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
}

variable "unique_id" {
  description = "A unique identifier for the deployment"
  type        = string
}

variable "input_bucket_name" {
  description = "Name of the bucket containing the function ZIP file"
  type        = string
}

variable "output_bucket_name" {
  description = "Name of the bucket containing the Parquet files"
  type        = string
}

variable "function_zip" {
  description = "Name of the ZIP file containing the function code (e.g. bigquery-map-tables-vX.X.X.zip)"
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for the function"
  type        = string
}

variable "iam_dependencies" {
  description = "Dependencies for IAM permissions to be applied before creating the function"
  type        = list(any)
  default     = []
}
