/**
* CANedge Input Bucket Creation on Google Cloud Platform
* Creates an input bucket with appropriate CORS settings for CANedge data
*/

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.84.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
  
  # Using local state for input bucket creation
  # This keeps the deployment simple without requiring remote state management
}

provider "google" {
  project = var.project
  region  = var.region
}

# Create the input bucket
resource "google_storage_bucket" "input_bucket" {
  name     = var.bucket_name
  location = var.region
  
  uniform_bucket_level_access = true

  # CORS configuration for CANedge device uploads
  cors {
    origin          = ["*"]
    method          = ["GET", "OPTIONS", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# CORS settings are now directly in the bucket resource

# Create HMAC key for S3 interoperability
resource "google_storage_hmac_key" "key" {
  service_account_email = google_service_account.storage_admin.email
}

# Generate a random string for service account naming
resource "random_id" "sa_prefix" {
  byte_length = 4
}

# Service account for HMAC key
resource "google_service_account" "storage_admin" {
  # Use a random ID to ensure we stay within naming constraints
  account_id   = "sa-canedge-${random_id.sa_prefix.hex}"
  display_name = "Storage Admin for ${var.bucket_name}"
}

# Grant bucket-specific permissions to the service account
resource "google_storage_bucket_iam_binding" "bucket_object_admin" {
  bucket = google_storage_bucket.input_bucket.name
  role   = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_service_account.storage_admin.email}"
  ]
}
