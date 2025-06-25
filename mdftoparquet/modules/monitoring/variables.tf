/**
* Variables for the Monitoring Module (Logging metrics and alerting)
*/

variable "project" {
  description = "GCP Project ID"
  type        = string
}

variable "unique_id" {
  description = "Unique identifier to namespace resources"
  type        = string
}

variable "notification_email" {
  description = "Email address to receive alert notifications"
  type        = string
}

variable "function_name" {
  description = "Name of the Cloud Function to monitor"
  type        = string
}
