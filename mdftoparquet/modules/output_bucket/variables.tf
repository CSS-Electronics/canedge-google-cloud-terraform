variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for bucket location"
  type        = string
}

variable "input_bucket_name" {
  description = "Name of the existing input bucket"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier to namespace resources"
  type        = string
}
