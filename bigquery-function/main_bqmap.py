import functions_framework
import os
import logging
from google.cloud import storage, bigquery

# Setup logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

@functions_framework.http
def map_bigquery_tables(request):
    """HTTP Cloud Function to map tables in BigQuery based on parquet files in a bucket.
    Args:
        request (flask.Request): The request object.
    Returns:
        A response with the mapping results.
    """
    # Get environment variables
    bucket_output_name = os.environ.get('OUTPUT_BUCKET')
    dataset_id = os.environ.get('DATASET_ID')
    
    # Log the start of execution
    logger.info(f"\n\nStarting BigQuery table mapping - will trawl bucket '{bucket_output_name}' to identify BigQuery tables based on the Parquet data lake structure")
    
    if not bucket_output_name or not dataset_id:
        return ({
            'status': 'error',
            'message': 'Missing required environment variables: OUTPUT_BUCKET and/or DATASET_ID'
        }, 400)
    
    storage_client = storage.Client()
    client = bigquery.Client()
    
    try:
        bucket = storage_client.get_bucket(bucket_output_name)
    except Exception as e:
        return ({
            'status': 'error',
            'message': f'Failed to get bucket {bucket_output_name}: {str(e)}'
        }, 500)
    
    results = {
        'deleted': [],
        'created': [],
        'failed': []
    }
    
    # Get project ID from the BigQuery client (for table naming)
    project_id = client.project
    dataset_ref = client.dataset(dataset_id)
    
    # Delete all existing tables in the dataset
    logger.info(f"Deleting all existing tables in dataset {dataset_id}...")
    deleted_count = 0
    tables = list(client.list_tables(dataset_ref))  # List all tables
    for table in tables:
        try:
            client.delete_table(table.reference)
            logger.info(f"- Deleted table {table.table_id}")
            results['deleted'].append({
                'table_id': table.table_id
            })
            deleted_count += 1
        except Exception as e:
            logger.warning(f"Failed to delete table {table.table_id}: {e}")
    
    logger.info(f"Deleted {deleted_count} existing tables from dataset {dataset_id}")
    
    # Crawl the bucket to get all unique combinations of deviceid and message
    logger.info(f"Scanning bucket {bucket_output_name} for Parquet files...")
    prefixes = set()
    blobs = bucket.list_blobs()
    for blob in blobs:
        parts = blob.name.split('/')
        if len(parts) >= 3:
            device_message = '/'.join(parts[0:2])
            prefixes.add(device_message)
    
    logger.info(f"Found {len(prefixes)} unique device/message combinations")
    
    # Process each unique deviceid/message combination
    for prefix in prefixes:
        deviceid, message = prefix.split('/')
        table_id = f"{project_id}.{dataset_id}.tbl_{deviceid}_{message}"
        
        # Construct the URI pattern to match Parquet files for the combination
        source_uris = [f"gs://{bucket_output_name}/{prefix}/*"]
    
        # Create an external table in BigQuery
        external_config = bigquery.ExternalConfig('PARQUET')
        external_config.source_uris = source_uris
        external_config.autodetect = True
        external_config.ignore_unknown_values = True  # Set to ignore unknown values
    
        table = bigquery.Table(table_id)
        table.external_data_configuration = external_config
    
        try:
            # Create the table in BigQuery
            created_table = client.create_table(table)  # Make an API request.
            results['created'].append({
                'table_id': created_table.table_id
            })
            logger.info(f"- SUCCESS: Created table {created_table.table_id}")
        except Exception as e:
            results['failed'].append({
                'table_id': table_id,
                'error': str(e)
            })
            logger.info(f"- WARNING: Failed to create table {table_id}, error: {str(e)}")
                
    # Create a summary message
    summary_message = f"Deleted {len(results['deleted'])} tables, created {len(results['created'])} tables, and failed for {len(results['failed'])} tables."
    
    # Log the summary
    logger.info(summary_message)
    
    # Create the response object
    response = {
        'status': 'success',
        'results': results,
        'message': summary_message
    }
    
    # Return the response for API consumers
    return (response, 200)


