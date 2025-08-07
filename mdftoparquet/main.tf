/**
* CANedge MDF4-to-Parquet Pipeline on Google Cloud Platform
* Root module that calls all child modules
*/

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.84.0"
    }
  }
  
  # Store state in input bucket
  # The actual bucket name is provided via -backend-config during terraform init
  backend "gcs" {
    prefix = "terraform/state/mdftoparquet"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

# Create output bucket module
module "output_bucket" {
  source = "./modules/output_bucket"

  project          = var.project
  region           = var.region
  input_bucket_name = var.input_bucket_name
  unique_id        = var.unique_id
}

# IAM service account and permissions
module "iam" {
  source = "./modules/iam"

  project          = var.project
  unique_id        = var.unique_id
  input_bucket_name = var.input_bucket_name
  output_bucket_name = module.output_bucket.output_bucket_name
}



# Cloud Function for MDF4 to Parquet conversion
module "cloud_function" {
  source = "./modules/cloud_function"

  project              = var.project
  region               = var.region
  unique_id            = var.unique_id
  input_bucket_name    = var.input_bucket_name
  output_bucket_name   = module.output_bucket.output_bucket_name
  service_account_email = module.iam.service_account_email
  function_zip         = var.function_zip
}

# Cloud Function for MDF4 to Parquet backlog processing
module "cloud_function_backlog" {
  source = "./modules/cloud_function_backlog"

  project              = var.project
  region               = var.region
  unique_id            = var.unique_id
  input_bucket_name    = var.input_bucket_name
  output_bucket_name   = module.output_bucket.output_bucket_name
  service_account_email = module.iam.service_account_email
  function_zip_backlog = var.function_zip_backlog
  
  depends_on = [
    module.iam
  ]
}

# Cloud Function for Parquet data lake aggregation
module "cloud_function_aggregation" {
  source = "./modules/cloud_function_aggregation"

  project              = var.project
  region               = var.region
  unique_id            = var.unique_id
  input_bucket_name    = var.input_bucket_name
  output_bucket_name   = module.output_bucket.output_bucket_name
  service_account_email = module.iam.service_account_email
  function_zip_aggregation = var.function_zip_aggregation
  
  depends_on = [
    module.iam
  ]
}


# Cloud Scheduler for daily triggering of the Backlog function
module "cloud_scheduler_backlog" {
  source = "./modules/cloud_scheduler_backlog"

  project              = var.project
  region               = var.region
  unique_id            = var.unique_id
  service_account_email = module.iam.service_account_email
  cloud_function_id    = module.cloud_function_backlog.backlog_function_id
  schedule             = var.scheduler_cron
  time_zone            = var.scheduler_timezone
  
  depends_on = [
    module.cloud_function_backlog
  ]
}


# Cloud Scheduler for daily triggering of the Aggregation function
module "cloud_scheduler_aggregation" {
  source = "./modules/cloud_scheduler_aggregation"

  project              = var.project
  region               = var.region
  unique_id            = var.unique_id
  service_account_email = module.iam.service_account_email
  cloud_function_id    = module.cloud_function_aggregation.aggregation_function_id
  schedule             = var.scheduler_cron
  time_zone            = var.scheduler_timezone
  
  depends_on = [
    module.cloud_function_aggregation
  ]
}

# Monitoring module for logging metrics and alert policies
module "monitoring" {
  source = "./modules/monitoring"

  project            = var.project
  unique_id          = var.unique_id
  notification_email = var.notification_email
  function_name      = module.cloud_function.function_name
  
  depends_on = [
    module.cloud_function
  ]
}
