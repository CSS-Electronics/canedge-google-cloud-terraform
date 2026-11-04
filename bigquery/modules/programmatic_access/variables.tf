variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier for resources"
  type        = string
}

variable "input_bucket_name" {
  description = "Name of the input bucket"
  type        = string
}

variable "output_bucket_name" {
  description = "Name of the output bucket (<input>-parquet)"
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset ID of the data lake"
  type        = string
}
