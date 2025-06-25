#!/bin/bash
# CANedge GCP BigQuery Deployment - One-Command Deployment Script

# Check if the script is being executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Check if script has execute permissions (skip on Windows where chmod doesn't apply)
  if [[ "$(uname -s)" != CYGWIN* ]] && [[ "$(uname -s)" != MINGW* ]] && [[ "$(uname -s)" != MSYS* ]]; then
    if [[ ! -x "${BASH_SOURCE[0]}" ]]; then
      echo -e "\033[1;31mERROR: Permission denied\033[0m"
      echo "This script is not executable. Run the following command first:"
      script_name=$(basename "${BASH_SOURCE[0]}")
      echo "  chmod +x ${script_name}"
      exit 1
    fi
  fi
fi

# Display help information
show_help() {
  echo "CANedge BigQuery - Automated Deployment"
  echo
  echo "Usage:"
  echo "  ./deploy_bigquery.sh [options]"
  echo
  echo "Required:"
  echo "  -p, --project PROJECT_ID    GCP Project ID"
  echo "  -b, --bucket BUCKET_NAME    Input bucket name"
  echo "  -i, --id UNIQUE_ID          Unique identifier for BigQuery resources"
  echo "  -d, --dataset DATASET_ID    BigQuery dataset ID"
  echo "  -z, --zip ZIP_FILE          BigQuery table mapping function ZIP file (e.g. bigquery-map-tables-vX.X.X.zip)"
  echo
  echo "Optional:"
  echo "  -y, --auto-approve          Skip approval prompt"
  echo "  -h, --help                  Show this help message"
  echo
  echo "Example:"
  echo "  ./deploy_bigquery.sh --project my-project-123 --bucket canedge-test-bucket-gcp --id canedge-demo --dataset lakedataset1 --zip bigquery-map-tables-vX.X.X.zip"
}

# Default values
AUTO_APPROVE="-auto-approve" # Auto-approve by default

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
      UNIQUE_ID="$2"
      shift 2
      ;;
    -d|--dataset)
      DATASET_ID="$2"
      shift 2
      ;;
    -z|--zip)
      ZIP_FILE="$2"
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

# Check if project ID is provided
if [ -z "$PROJECT_ID" ]; then
  echo "Error: Project ID is required. Please specify with --project flag."
  show_help
  exit 1
fi

# Check if bucket name is provided
if [ -z "$BUCKET_NAME" ]; then
  echo "Error: Input bucket name is required. Please specify with --bucket flag."
  show_help
  exit 1
fi

# Check if unique ID is provided
if [ -z "$UNIQUE_ID" ]; then
  echo "Error: Unique ID is required. Please specify with --id flag."
  show_help
  exit 1
fi

# Check if dataset ID is provided
if [ -z "$DATASET_ID" ]; then
  echo "Error: Dataset ID is required. Please specify with --dataset flag."
  show_help
  exit 1
fi

# Check if function ZIP is provided
if [ -z "$ZIP_FILE" ]; then
  echo "Error: BigQuery function ZIP filename is required. Please specify with --zip flag."
  show_help
  exit 1
fi

# Automatically configure the current project
echo "Setting project to '$PROJECT_ID'..."
gcloud config set project "$PROJECT_ID"
echo "✓ Project set to '$PROJECT_ID'."

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable cloudresourcemanager.googleapis.com iam.googleapis.com cloudfunctions.googleapis.com bigquery.googleapis.com cloudbuild.googleapis.com eventarc.googleapis.com --quiet
echo "✓ Required APIs enabled (Cloud Resource Manager, IAM, Cloud Functions, BigQuery, Cloud Build, Eventarc)."


# Checking input bucket...
echo "Checking input bucket..."
if ! gsutil ls -b "gs://${BUCKET_NAME}"; then
  echo "❌ ERROR: Input bucket '${BUCKET_NAME}' not found in project '${PROJECT_ID}'."
  echo "Please create the input bucket first using deploy_input_bucket.sh"
  exit 1
else
  echo "✓ Input bucket found."
fi

# Auto-detecting region from input bucket
echo "Auto-detecting region from input bucket..."
REGION=$(gsutil ls -L -b "gs://${BUCKET_NAME}" | grep -E "Location constraint:" | awk '{print $3}' | tr '[:upper:]' '[:lower:]')
echo "✓ Detected region: ${REGION}"

# Check if output bucket (parquet) exists
OUTPUT_BUCKET_NAME="${BUCKET_NAME}-parquet"
echo "Checking if Parquet output bucket exists..."
if gsutil ls -b "gs://${OUTPUT_BUCKET_NAME}" > /dev/null 2>&1; then
  echo "✓ Parquet output bucket exists. BigQuery tables can be mapped to this bucket."
else
  echo "⚠️ Warning: Parquet output bucket '${OUTPUT_BUCKET_NAME}' not found."
  echo "   Please deploy the MDF-to-Parquet pipeline first to create this bucket."
  echo "   Continue anyway? (y/n)"
  read -r response
  if [[ "$response" != "y" && "$response" != "Y" ]]; then
    echo "Deployment cancelled."
    exit 1
  fi
fi

# Check if service accounts already exist
ADMIN_SA_NAME="${UNIQUE_ID}-bigquery-admin"
USER_SA_NAME="${UNIQUE_ID}-bigquery-user"
ADMIN_SA_EMAIL="${ADMIN_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
USER_SA_EMAIL="${USER_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Checking if service accounts already exist..."
if gcloud iam service-accounts list --project="$PROJECT_ID" --filter="email:${ADMIN_SA_EMAIL}" --format="value(email)" | grep -q "${ADMIN_SA_NAME}"; then
  echo "✓ BigQuery Admin service account already exists, will be reused"
  ADMIN_SA_EXISTS=true
else
  echo "✓ BigQuery Admin service account will be created"
  ADMIN_SA_EXISTS=false
fi

if gcloud iam service-accounts list --project="$PROJECT_ID" --filter="email:${USER_SA_EMAIL}" --format="value(email)" | grep -q "${USER_SA_NAME}"; then
  echo "✓ BigQuery User service account already exists, will be reused"
  USER_SA_EXISTS=true
else
  echo "✓ BigQuery User service account will be created"
  USER_SA_EXISTS=false
fi

# Check if dataset already exists
echo "Checking if BigQuery dataset already exists..."
if bq ls --project_id="${PROJECT_ID}" | grep -q "${DATASET_ID}"; then
  echo "✓ BigQuery dataset '${DATASET_ID}' already exists, will be reused"
  DATASET_EXISTS=true
else
  echo "✓ BigQuery dataset '${DATASET_ID}' will be created"
  DATASET_EXISTS=false
fi

# Print deployment configuration
echo "Deploying BigQuery Analytics:"
echo "   - Project ID:    $PROJECT_ID"
echo "   - Region:        $REGION"
echo "   - Input Bucket:  $BUCKET_NAME"
echo "   - Dataset ID:    $DATASET_ID"
echo "   - Unique ID:     $UNIQUE_ID"
echo

# Move to the bigquery directory
cd bigquery

# Initialize Terraform with backend config pointing to input bucket
echo "Initializing Terraform with state stored in input bucket..."
terraform init -reconfigure \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="prefix=terraform/state/bigquery" > /dev/null

# Import existing resources if they exist
if [ "$DATASET_EXISTS" = true ]; then
  echo "Importing existing dataset into Terraform state..."
  terraform import -auto-approve -var="project=${PROJECT_ID}" -var="region=${REGION}" \
    module.dataset.google_bigquery_dataset.main "${PROJECT_ID}:${DATASET_ID}" > /dev/null 2>&1 || true
fi

if [ "$ADMIN_SA_EXISTS" = true ]; then
  echo "Importing existing BigQuery Admin service account into Terraform state..."
  terraform import -auto-approve -var="project=${PROJECT_ID}" \
    module.service_accounts.google_service_account.bigquery_admin "projects/${PROJECT_ID}/serviceAccounts/${ADMIN_SA_EMAIL}" > /dev/null 2>&1 || true
fi

if [ "$USER_SA_EXISTS" = true ]; then
  echo "Importing existing BigQuery User service account into Terraform state..."
  terraform import -auto-approve -var="project=${PROJECT_ID}" \
    module.service_accounts.google_service_account.bigquery_user "projects/${PROJECT_ID}/serviceAccounts/${USER_SA_EMAIL}" > /dev/null 2>&1 || true
fi

# Apply Terraform configuration with variables
echo "Deploying resources (this may take a few minutes) ... "
terraform apply -auto-approve \
  -var="project=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="input_bucket_name=${BUCKET_NAME}" \
  -var="unique_id=${UNIQUE_ID}" \
  -var="dataset_id=${DATASET_ID}" \
  -var="function_zip=${ZIP_FILE}"

# Check if the deployment was successful
DEPLOY_STATUS=$?
if [ $DEPLOY_STATUS -eq 0 ]; then
  # Extract important values from terraform output
  DATASET_ID=$(terraform output -raw dataset_id 2>/dev/null)
  ADMIN_SA=$(terraform output -raw bigquery_admin_service_account_email 2>/dev/null)
  USER_SA=$(terraform output -raw bigquery_user_service_account_email 2>/dev/null)
  FUNCTION_URI=$(terraform output -raw function_uri 2>/dev/null)
  
  # Get the service account keys (base64-encoded JSON)
  ADMIN_KEY=$(terraform output -raw bigquery_admin_key 2>/dev/null)
  USER_KEY=$(terraform output -raw bigquery_user_key 2>/dev/null)
  
  # Decode the base64 keys to get the JSON content
  ADMIN_KEY_JSON=$(echo "${ADMIN_KEY}" | base64 --decode)
  USER_KEY_JSON=$(echo "${USER_KEY}" | base64 --decode)
  
  # Create local files and upload them to the input bucket
  ADMIN_KEY_FILE="${UNIQUE_ID}-bigquery-admin-account.json"
  USER_KEY_FILE="${UNIQUE_ID}-bigquery-user-account.json"
  
  echo "${ADMIN_KEY_JSON}" > ${ADMIN_KEY_FILE}
  echo "${USER_KEY_JSON}" > ${USER_KEY_FILE}
  
  # Upload to the input bucket
  echo "Uploading service account keys to input bucket..."
  gsutil cp ${ADMIN_KEY_FILE} gs://${BUCKET_NAME}/${ADMIN_KEY_FILE}
  gsutil cp ${USER_KEY_FILE} gs://${BUCKET_NAME}/${USER_KEY_FILE}
  
  # Clean up the local files
  rm ${ADMIN_KEY_FILE} ${USER_KEY_FILE}

  echo
  echo
  echo
  echo "---------------------------"
  echo "✅  Deployment successful!"
  echo
  echo "BigQuery details:"
  echo
  echo "Project ID:           ${PROJECT_ID}"
  echo "Dataset ID:           ${DATASET_ID}"
  echo "Admin service account: ${ADMIN_SA}"
  echo "User service account:  ${USER_SA}"
  echo
  echo "Service account keys saved to:"
  echo "  - gs://${BUCKET_NAME}/${ADMIN_KEY_FILE}"
  echo "  - gs://${BUCKET_NAME}/${USER_KEY_FILE}"
  echo 
  echo "To map your Parquet data to BigQuery tables:"
  echo "1. Open the Cloud Function in your browser:"
  echo "   https://console.cloud.google.com/functions/details/${REGION}/${UNIQUE_ID}-bq-map-tables?project=${PROJECT_ID}"
  echo "2. Click the 'Test' button at the top of the page"
  echo "3. Copy the default 'CLI test command'"
  echo "4. Click 'Test in Cloud Shell' button"
  echo "5. Paste the command into Cloud Shell and press Enter"
  echo "6. View detailed execution logs in the 'Logs' tab of the function"
  echo
  echo "The function will delete all existing tables in the dataset and create new ones"
  echo "by scanning the output bucket for Parquet files based on the device/message structure."
  echo
fi
