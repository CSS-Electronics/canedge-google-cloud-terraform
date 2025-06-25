terraform {
  required_version = ">= 0.14.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    # These values are set by the terraform init command from deploy_bigquery.sh
    # bucket = "<input_bucket_name>"
    # prefix = "terraform/state/bigquery"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

# BigQuery Dataset
module "dataset" {
  source     = "./modules/dataset"
  project    = var.project
  region     = var.region
  dataset_id = var.dataset_id
  unique_id  = var.unique_id
}

# Service Accounts
module "service_accounts" {
  source    = "./modules/service_accounts"
  project   = var.project
  unique_id = var.unique_id
}

# BigQuery Table Mapping Cloud Function
module "cloud_function" {
  source              = "./modules/cloud_function"
  project             = var.project
  region              = var.region
  unique_id           = var.unique_id
  input_bucket_name   = var.input_bucket_name
  output_bucket_name  = "${var.input_bucket_name}-parquet"
  dataset_id          = var.dataset_id
  function_zip        = var.function_zip
  service_account_email = module.service_accounts.bigquery_admin_service_account_email
  # Ensure IAM permissions are created before the function
  iam_dependencies    = [
    module.service_accounts.bigquery_admin_service_account_email
  ]
}

# Output variables for use in scripts and documentation
output "project_id" {
  value = var.project
}

output "dataset_id" {
  value = module.dataset.dataset_id
}

output "bigquery_admin_service_account_email" {
  value = module.service_accounts.bigquery_admin_service_account_email
}

output "bigquery_user_service_account_email" {
  value = module.service_accounts.bigquery_user_service_account_email
}

output "bigquery_admin_key" {
  value     = module.service_accounts.bigquery_admin_key
  sensitive = true
}

output "bigquery_user_key" {
  value     = module.service_accounts.bigquery_user_key
  sensitive = true
}

output "function_uri" {
  description = "URI to trigger the BigQuery table mapping function"
  value       = module.cloud_function.function_uri
}
