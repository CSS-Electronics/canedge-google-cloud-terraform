/**
* Input variables for the CANedge Input Bucket Terraform Stack
*/

variable "project" {
  description = "GCP Project ID where resources will be deployed"
  type        = string
}

variable "region" {
  description = "GCP region for resource deployment (e.g., europe-west1)"
  type        = string
}

variable "bucket_name" {
  description = "Name of the input bucket to be created"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier to namespace resources"
  type        = string
  default     = "canedge"
}
