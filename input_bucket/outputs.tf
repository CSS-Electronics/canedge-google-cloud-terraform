/**
* Output variables for the CANedge Input Bucket Terraform Stack
*/

output "endpoint" {
  description = "Google Cloud Storage endpoint"
  value       = "http://storage.googleapis.com"
}

output "port" {
  description = "Port number for GCS endpoint"
  value       = 80
}

output "bucket_name" {
  description = "Name of the created input bucket"
  value       = google_storage_bucket.input_bucket.name
}

output "bucket_region" {
  description = "Region where the bucket was created"
  value       = google_storage_bucket.input_bucket.location
}

output "s3_interoperability_access_key" {
  description = "S3 interoperability access key"
  value       = google_storage_hmac_key.key.access_id
}

output "s3_interoperability_secret_key" {
  description = "S3 interoperability secret key"
  value       = google_storage_hmac_key.key.secret
  sensitive   = true
}
