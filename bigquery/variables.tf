variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "input_bucket_name" {
  description = "Name of the input bucket where the state will be stored"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier for resources"
  type        = string
  default     = "canedge-demo"
}

variable "dataset_id" {
  description = "BigQuery dataset ID"
  type        = string
  default     = "lakedataset1"
}

variable "function_zip" {
  description = "Name of the ZIP file containing the BigQuery table mapping function code (e.g. bigquery-map-tables-vX.X.X.zip)"
  type        = string
}
