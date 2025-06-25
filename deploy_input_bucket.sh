#!/bin/bash
# CANedge GCP Input Bucket - One-Command Deployment Script

# Display help information
show_help() {
  echo "CANedge GCP Input Bucket - Automated Deployment"
  echo
  echo "Usage:"
  echo "  ./deploy_input_bucket.sh [options]"
  echo
  echo "Options:"
  echo "  -p, --project PROJECT_ID    GCP Project ID (REQUIRED)"
  echo "  -r, --region REGION         GCP region for deployment (default: europe-west1)"
  echo "  -b, --bucket BUCKET_NAME    Input bucket name to create (REQUIRED)"
  # Removed --id parameter as it's not relevant for input bucket creation
  echo "  -y, --auto-approve          Skip approval prompt"
  echo "  -h, --help                  Show this help message"
  echo
  echo "Example:"
  echo "  ./deploy_input_bucket.sh --project my-project-123 --region europe-west1 --bucket canedge-test-bucket-gcp"
}

# Default values
REGION="europe-west1"
AUTO_APPROVE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      PROJECT_ID="$2"
      shift 2
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    -b|--bucket)
      BUCKET_NAME="$2"
      shift 2
      ;;
    -i|--id)
      echo "Warning: --id parameter is not used for input bucket creation and will be ignored."
      shift 2
      ;;
    -y|--auto-approve)
      AUTO_APPROVE="-auto-approve"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check if required parameters are provided
if [ -z "$PROJECT_ID" ]; then
  echo "Error: Project ID is required. Please specify with --project flag."
  show_help
  exit 1
fi

if [ -z "$BUCKET_NAME" ]; then
  echo "Error: Bucket name is required. Please specify with --bucket flag."
  show_help
  exit 1
fi

# Automatically configure the current project
echo "Setting project to '$PROJECT_ID'..."
gcloud config set project "$PROJECT_ID"
echo "✓ Project set to '$PROJECT_ID'."

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable cloudresourcemanager.googleapis.com iam.googleapis.com storage-api.googleapis.com storage.googleapis.com --quiet
echo "✓ Required APIs enabled (Cloud Resource Manager, IAM, Storage)."


# Print deployment configuration
echo "Deploying CANedge GCP Input Bucket with the following configuration:"
echo "   - Project ID:    $PROJECT_ID"
echo "   - Region:        $REGION"
echo "   - Bucket Name:   $BUCKET_NAME"
# Removed unique ID output as it's not used
echo

# Move to the input_bucket directory
cd input_bucket

# Initialize Terraform with local state first
echo "Initializing Terraform with local state..."
terraform init

# Apply the Terraform configuration to create the bucket
echo "Applying Terraform configuration to create the input bucket..."

# Always auto-approve to avoid having to type "yes"
if [ -z "$AUTO_APPROVE" ]; then
  AUTO_APPROVE="-auto-approve"
fi

# Run terraform apply with all progress visible but hide the outputs at the end
TERRAFORM_OUTPUT=$(terraform apply ${AUTO_APPROVE} \
  -var="project=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="bucket_name=${BUCKET_NAME}")

# Check if the deployment was successful
if [ $? -ne 0 ]; then
  echo "❌  Initial deployment failed."
  exit 1
fi

# Using local state only - no need to reinitialize with remote state

# Show the outputs - only show our formatted output, not the default Terraform output
echo
echo
echo 
echo "---------------------------"
echo "✅  Deployment successful!"
echo
echo "CANedge S3 configuration details:"
echo
echo "Endpoint:         $(terraform output -raw endpoint)"
echo "Port:             $(terraform output -raw port)"
echo "Bucket name:      $(terraform output -raw bucket_name)"
echo "Region:           $(terraform output -raw bucket_region | tr '[:upper:]' '[:lower:]')"
echo "Request style:    Path style"
echo "AccessKey:        $(terraform output -raw s3_interoperability_access_key)"
echo "SecretKey format: Plain"
echo "SecretKey:        $(terraform output -raw s3_interoperability_secret_key)"
echo 
echo
