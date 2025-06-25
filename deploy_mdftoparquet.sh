#!/bin/bash
# CANedge GCP MDF4-to-Parquet Pipeline - One-Command Deployment Script

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
  echo "CANedge MDF4-to-Parquet Pipeline - Automated Deployment"
  echo
  echo "Usage:"
  echo "  ./deploy_mdftoparquet.sh [options]"
  echo
  echo "Required:"
  echo "  -p, --project PROJECT_ID    GCP Project ID"
  echo "  -b, --bucket BUCKET_NAME    Input bucket name"
  echo "  -i, --id UNIQUE_ID          Unique identifier for pipeline resources"
  echo "  -z, --zip FUNCTION_ZIP      Cloud Function ZIP filename (e.g. mdf-to-parquet-google-function-vX.X.X.zip)"
  echo
  echo "Optional:"
  echo "  -e, --email EMAIL           Email address to receive notifications"
  echo "  -y, --auto-approve          Skip approval prompt"
  echo "  -h, --help                  Show this help message"
  echo
  echo "Example:"
  echo "  ./deploy_mdftoparquet.sh --project my-project-123 --bucket canedge-test-bucket-gcp --id canedge-demo --email user@example.com --zip mdf-to-parquet-google-function-vX.X.X.zip"
}

# Default values
AUTO_APPROVE="-auto-approve" # Auto-approve by default
NOTIFICATION_EMAIL=""         # Email for notifications
# No default for UNIQUE_ID or FUNCTION_ZIP - user must provide them

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
    -e|--email)
      NOTIFICATION_EMAIL="$2"
      shift 2
      ;;
    -z|--zip)
      FUNCTION_ZIP="$2"
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

# Automatically configure the current project
echo "Setting project to '$PROJECT_ID'..."
gcloud config set project "$PROJECT_ID"
echo "✓ Project set to '$PROJECT_ID'."

# Check authentication status
echo "Checking GCP authentication status..."
AUTH_CHECK=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>&1)
if [[ -z "$AUTH_CHECK" ]]; then
  echo "❌ ERROR: Not authenticated with GCP. Please run 'gcloud auth login' first."
  exit 1
fi
echo "✓ Authenticated as $AUTH_CHECK"

# Enable required APIs
echo "Enabling required GCP APIs..."
echo "- Enabling Cloud Resource Manager API..."
gcloud services enable cloudresourcemanager.googleapis.com --quiet
echo "- Enabling IAM API..."
gcloud services enable iam.googleapis.com --quiet
echo "- Enabling Cloud Functions API..."
gcloud services enable cloudfunctions.googleapis.com --quiet
echo "- Enabling Cloud Run API..."
gcloud services enable run.googleapis.com --quiet
echo "- Enabling Cloud Build API..."
gcloud services enable cloudbuild.googleapis.com --quiet
echo "- Enabling Eventarc API..."
gcloud services enable eventarc.googleapis.com --quiet
echo "✓ All required APIs have been enabled."

# Ensure Eventarc service agent has proper permissions
echo "Setting up Eventarc service agent permissions..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com" \
  --role="roles/eventarc.serviceAgent" --quiet
echo "✓ Eventarc service agent permissions set."
echo "Waiting 20 seconds for permissions to propagate..."
sleep 20

# Check if bucket name is provided
if [ -z "$BUCKET_NAME" ]; then
  echo "Error: Input bucket name is required. Please specify with --bucket flag."
  show_help
  exit 1
fi

# Checking input bucket...
echo "Checking input bucket..."
gsutil ls -b "gs://${BUCKET_NAME}" 2>&1
BUCKET_CHECK_RESULT=$?
if [ $BUCKET_CHECK_RESULT -ne 0 ]; then
  echo "❌ ERROR: Input bucket '${BUCKET_NAME}' not found in project '${PROJECT_ID}'."
  echo "Please create the input bucket first using deploy_input_bucket.sh"
  exit 1
else
  echo "✓ Input bucket found."
fi

# Check if unique ID is provided
if [ -z "$UNIQUE_ID" ]; then
  echo "Error: Unique ID is required. Please specify with --id flag."
  show_help
  exit 1
fi

# Check if function ZIP is provided
if [ -z "$FUNCTION_ZIP" ]; then
  echo "Error: Function ZIP filename is required. Please specify with --zip flag."
  show_help
  exit 1
fi

# Auto-detecting region from input bucket
echo "Auto-detecting region from input bucket..."
REGION=$(gsutil ls -L -b "gs://${BUCKET_NAME}" | grep -E "Location constraint:" | awk '{print $3}' | tr '[:upper:]' '[:lower:]')
echo "✓ Detected region: ${REGION}"

# Check if output bucket already exists
OUTPUT_BUCKET_NAME="${BUCKET_NAME}-parquet"
echo "Checking if output bucket already exists..."
gsutil ls -b "gs://${OUTPUT_BUCKET_NAME}" 2>&1
OUTPUT_BUCKET_CHECK=$?
if [ $OUTPUT_BUCKET_CHECK -eq 0 ]; then
  echo "✓ Output bucket already exists, will be reused"
  BUCKET_EXISTS=true
else
  echo "✓ Output bucket will be created"
  BUCKET_EXISTS=false
fi

# Check if service account already exists
SA_NAME="${UNIQUE_ID}-function-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Checking if service account already exists..."

# Check if service account is visible in the list
if gcloud iam service-accounts list --project="$PROJECT_ID" --filter="email:${SA_EMAIL}" --format="value(email)" | grep -q "${SA_NAME}"; then
  echo "✓ Service account already exists, will be reused"
  SA_EXISTS=true
else
  # Check if service account is in soft-delete state
  TEMP_CHECK=$(gcloud iam service-accounts create "${SA_NAME}-probe" --project="$PROJECT_ID" 2>&1 || true)
  if [[ $TEMP_CHECK == *"already exists"* ]]; then
    echo "✓ Service account appears to be in soft-delete state"
    echo "✓ Will create new service account with ID ${UNIQUE_ID}-function-sa"
    SA_EXISTS=false
  else
    # If we were able to create the probe account, delete it immediately 
    if [[ $TEMP_CHECK != *"PERMISSION_DENIED"* ]]; then
      gcloud iam service-accounts delete "${SA_NAME}-probe@${PROJECT_ID}.iam.gserviceaccount.com" --project="$PROJECT_ID" --quiet || true
    fi
    echo "✓ Service account will be created"
    SA_EXISTS=false
  fi
fi

# Check if cloud function already exists
FUNCTION_NAME="${UNIQUE_ID}-mdf-to-parquet"
echo "Checking if cloud function already exists..."
gcloud functions describe "$FUNCTION_NAME" --gen2 --project="$PROJECT_ID" --region="$REGION" 2>&1
FUNCTION_CHECK=$?
if [ $FUNCTION_CHECK -eq 0 ]; then
  echo "✓ Cloud function already exists, will be reused"
  FUNCTION_EXISTS=true
else
  echo "✓ Cloud function will be created"
  FUNCTION_EXISTS=false
fi

# Print deployment configuration
echo "Deploying MDF4-to-Parquet Pipeline:"
echo "   - Project ID:    $PROJECT_ID"
echo "   - Region:        $REGION"
echo "   - Input Bucket:  $BUCKET_NAME"
echo "   - Unique ID:     $UNIQUE_ID"
[ -n "$NOTIFICATION_EMAIL" ] && echo "   - Notifications: $NOTIFICATION_EMAIL"
echo

# Move to the mdftoparquet directory
cd mdftoparquet

# Initialize Terraform with backend config pointing to input bucket
echo "Initializing Terraform with state stored in input bucket..."
terraform init -reconfigure \
  -backend-config="bucket=${BUCKET_NAME}" \
  -backend-config="prefix=terraform/state/mdftoparquet"

# Check if the ZIP file exists in the bucket
echo "Checking if Cloud Function ZIP file exists in bucket..."
gsutil stat "gs://${BUCKET_NAME}/${FUNCTION_ZIP}" 2>&1
ZIP_CHECK=$?
if [ $ZIP_CHECK -eq 0 ]; then
  echo "✓ Found Cloud Function ZIP file '${FUNCTION_ZIP}' in bucket"
else
  echo "⚠️ Warning: Cloud Function ZIP file '${FUNCTION_ZIP}' not found in bucket '${BUCKET_NAME}'."
  if [[ "$AUTO_APPROVE" == "-auto-approve" ]]; then
    echo "   Auto-approve enabled, continuing anyway..."
  else
    echo "   You may need to upload it manually before the function will work correctly."
    echo "   Continue anyway? (y/n)"
    read -r response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
      echo "Deployment cancelled."
      exit 1
    fi
  fi
fi

# Import existing resources if they exist
if [ "$BUCKET_EXISTS" = true ]; then
  echo "Importing existing output bucket into Terraform state..."
  terraform import -auto-approve -var="project=${PROJECT_ID}" -var="region=${REGION}" \
    module.output_bucket.google_storage_bucket.output_bucket "${OUTPUT_BUCKET_NAME}" 2>&1 || true
fi

# If the service account exists, ensure it's imported into Terraform state
if [ "$SA_EXISTS" = true ]; then
  echo "Importing existing service account into Terraform state..."
  terraform import -auto-approve -var="project=${PROJECT_ID}" \
    module.iam.google_service_account.function_service_account "projects/${PROJECT_ID}/serviceAccounts/${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" 2>&1 || true
fi

if [ "$FUNCTION_EXISTS" = true ]; then
  echo "Importing existing cloud function into Terraform state..."
  terraform import -auto-approve -var="project=${PROJECT_ID}" -var="region=${REGION}" \
    module.cloud_function.google_cloudfunctions2_function.mdf_to_parquet_function "projects/${PROJECT_ID}/locations/${REGION}/functions/${FUNCTION_NAME}" 2>&1 || true
fi

# If notification email wasn't provided via command line, handle appropriately
if [ -z "$NOTIFICATION_EMAIL" ]; then
  if [[ "$AUTO_APPROVE" == "-auto-approve" ]]; then
    # Auto-approve is enabled, but we still need an email for the variable
    # Set a placeholder email as Terraform requires this variable
    echo "⚠️ Warning: No email provided. Notifications will be configured but no subscribers will receive them."
    NOTIFICATION_EMAIL="no-reply@example.com"
  else
    # Ask for email interactively
    echo -n "Enter email address for event notifications (leave blank to skip): "
    read -r NOTIFICATION_EMAIL
    echo
    if [ -z "$NOTIFICATION_EMAIL" ]; then
      echo "⚠️ Warning: No email provided. Notifications will be configured but no subscribers will receive them."
      echo
      # Set a placeholder email as Terraform requires this variable
      NOTIFICATION_EMAIL="no-reply@example.com"
    fi
  fi
fi

# Apply Terraform configuration with variables
if [ "$FUNCTION_EXISTS" = true ]; then
  echo "Updating existing resources and redeploying Cloud Function (this may take a few minutes)... "
  # Create a plan and apply it directly without requiring confirmation
  echo "Creating Terraform plan..."
  terraform plan -var="project=${PROJECT_ID}" \
    -var="region=${REGION}" \
    -var="input_bucket_name=${BUCKET_NAME}" \
    -var="unique_id=${UNIQUE_ID}" \
    -var="notification_email=${NOTIFICATION_EMAIL}" \
    -var="function_zip=${FUNCTION_ZIP}" \
    -out=tfplan
  
  # Apply the plan without asking for confirmation
  echo -e "\nApplying the plan (no confirmation needed)..."
  terraform apply -auto-approve tfplan
  
  # Clean up the plan file
  rm -f tfplan
else
  echo "Deploying new resources (this may take a few minutes) ... "
  # Run terraform apply with auto-approve
  terraform apply -auto-approve \
    -var="project=${PROJECT_ID}" \
    -var="region=${REGION}" \
    -var="input_bucket_name=${BUCKET_NAME}" \
    -var="unique_id=${UNIQUE_ID}" \
    -var="notification_email=${NOTIFICATION_EMAIL}" \
    -var="function_zip=${FUNCTION_ZIP}"
fi

# Check if the deployment was successful
DEPLOY_STATUS=$?
if [ $DEPLOY_STATUS -eq 0 ]; then
  # Deployment successful
  if [ "$FUNCTION_EXISTS" = true ]; then
    echo "Redeployment completed successfully."
  else
    echo "New deployment completed successfully."
  fi
  # Extract important values from terraform output
  OUTPUT_BUCKET=$(terraform output -raw output_bucket_name 2>/dev/null)
  FUNCTION_NAME=$(terraform output -raw cloud_function_name 2>/dev/null)
  SERVICE_ACCOUNT=$(terraform output -raw service_account_email 2>/dev/null)
  
  # Get the service account key (base64-encoded JSON)
  SA_KEY=$(terraform output -raw service_account_key 2>/dev/null)
  
  # Decode the base64 key to get the JSON content
  SA_KEY_JSON=$(echo "${SA_KEY}" | base64 --decode)
  
  # Create a local file and upload it to the input bucket
  KEY_FILE="${UNIQUE_ID}-service-account-key.json"
  echo "${SA_KEY_JSON}" > ${KEY_FILE}
  
  # Upload to the input bucket
  echo "Uploading service account key to input bucket..."
  gsutil cp ${KEY_FILE} gs://${BUCKET_NAME}/${KEY_FILE}
  
  # Clean up the local file
  rm ${KEY_FILE}
  
  echo
  echo
  echo
  echo "---------------------------"
  echo "✅  Deployment successful!"
  echo
  echo "MDF4-to-Parquet details:"
  echo
  echo "Input bucket:           ${BUCKET_NAME}"
  echo "Output bucket:          ${OUTPUT_BUCKET}"
  echo "Function name:          ${FUNCTION_NAME}"
  echo "Service account:        ${SERVICE_ACCOUNT}"
  echo
  echo "Service account key saved to: gs://${BUCKET_NAME}/${KEY_FILE}"
  echo
  echo 
fi
