/**
* Outputs for the BigQuery table mapping Cloud Function
*/

output "function_uri" {
  description = "URI to trigger the BigQuery table mapping function"
  value       = google_cloudfunctions2_function.bigquery_map_tables_function.service_config[0].uri
}

output "function_id" {
  description = "ID of the deployed Cloud Function"
  value       = google_cloudfunctions2_function.function.id
}
