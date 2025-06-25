resource "google_bigquery_dataset" "main" {
  dataset_id                  = var.dataset_id
  friendly_name               = "CANedge Parquet Data Lake"
  description                 = "Dataset for CANedge Parquet data lake"
  location                    = var.region
  default_table_expiration_ms = null

  labels = {
    environment = "production"
    managed_by  = "terraform"
    unique_id   = var.unique_id
  }
}
