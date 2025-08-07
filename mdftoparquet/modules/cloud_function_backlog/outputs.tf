output "function_name" {
  description = "Name of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.mdf_to_parquet_backlog_function.name
}

output "backlog_function_id" {
  description = "ID of the deployed backlog Cloud Function"
  value       = google_cloudfunctions2_function.mdf_to_parquet_backlog_function.id
}
