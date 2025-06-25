output "output_bucket_name" {
  description = "Name of the created output bucket for Parquet files"
  value       = google_storage_bucket.output_bucket.name
}
