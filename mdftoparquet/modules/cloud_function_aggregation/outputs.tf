output "function_name" {
  description = "Name of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.aggregation_function.name
}

output "aggregation_function_id" {
  description = "ID of the deployed Aggregation Cloud Function"
  value       = google_cloudfunctions2_function.aggregation_function.id
}
