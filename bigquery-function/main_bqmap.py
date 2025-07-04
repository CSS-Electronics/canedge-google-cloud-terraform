import functions_framework
import os
import re
import json
import logging
import tempfile
from google.cloud import storage, bigquery
from google.cloud.exceptions import Conflict
import pyarrow as pa
import pyarrow.parquet as pq

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
    

    
    # Crawl the bucket to get all unique combinations of device_id and message
    prefixes = set()
    devices = set()
    blobs = bucket.list_blobs()
    for blob in blobs:
        parts = blob.name.split('/')
        if len(parts) >= 3:
            top_prefix, message = parts[:2]
            if re.match(r"^[0-9A-F]{8}$", top_prefix):  # Ensure only valid device IDs
                prefixes.add(f"{top_prefix}/{message}")
                devices.add(top_prefix)

    # Ensure meta Parquet files are always created before table mappings
    metadata_list = []
    for device_id in devices:
        device_json_path = f"{device_id}/device.json"
        metaname = device_id.upper()
        
        try:
            # Assuming we should use the same bucket for input and output
            blob = bucket.blob(device_json_path)
            device_meta = json.loads(blob.download_as_text())
            log_meta = device_meta.get("log_meta", "")
            if log_meta:
                metaname = f"{log_meta} ({device_id.upper()})"
        except Exception as e:
            print(f"Unable to extract meta data from device.json for {device_id}: {e}")
        
        metadata_list.append({"MetaName": metaname, "DeviceId": device_id})

    # Save metadata to Parquet
    meta_path = "aggregations/devicemeta/2024/01/01/devicemeta.parquet"
    meta_table_id = f"{project_id}.{dataset_id}.tbl_aggregations_devicemeta"
    if metadata_list:
        meta_table = pa.Table.from_pydict({
            "MetaName": [item['MetaName'] for item in metadata_list],
            "DeviceId": [item['DeviceId'] for item in metadata_list]
        })
        
        with tempfile.NamedTemporaryFile(suffix=".parquet", delete=False) as temp_file:
            pq.write_table(meta_table, temp_file.name, compression='snappy')
            blob = bucket.blob(meta_path)
            blob.upload_from_filename(temp_file.name)
            print(f"Device meta Parquet file successfully written to gs://{bucket_output_name}/{meta_path}")

    # Create external table for devicemeta
    source_uris = [f"gs://{bucket_output_name}/{meta_path}"]
    external_config = bigquery.ExternalConfig('PARQUET')
    external_config.source_uris = source_uris
    external_config.autodetect = True
    meta_table = bigquery.Table(meta_table_id)
    meta_table.external_data_configuration = external_config
    try:
        client.create_table(meta_table)
        print(f"- Created devicemeta table {meta_table_id}")
        results['created'].append({
            'table_id': meta_table_id
        })
    except Conflict:
        print(f"- Devicemeta table {meta_table_id} already exists")
    except Exception as e:
        print(f"- Failed to create devicemeta table {meta_table_id}: {e}")
        results['failed'].append({
            'table_id': meta_table_id,
            'error': str(e)
        })

    # Process each device ID to create a messages table
    for device_id in devices:
        messages = set()
        for prefix in prefixes:
            if prefix.startswith(device_id):
                _, message = prefix.split('/')
                messages.add(message)
        
        messages_list = list(messages)
        messages_path = f"{device_id}/messages/2024/01/01/messages.parquet"
        messages_table_id = f"{project_id}.{dataset_id}.tbl_{device_id}_messages"
        
        # Create and upload messages Parquet file
        messages_table = pa.Table.from_pydict({"MessageName": messages_list})
        with tempfile.NamedTemporaryFile(suffix=".parquet", delete=False) as temp_file:
            pq.write_table(messages_table, temp_file.name, compression='snappy')
            blob = bucket.blob(messages_path)
            blob.upload_from_filename(temp_file.name)
            print(f"Messages Parquet file successfully written to gs://{bucket_output_name}/{messages_path}")
        
        # Create external table for messages
        source_uris = [f"gs://{bucket_output_name}/{messages_path}"]
        external_config.source_uris = source_uris
        messages_table = bigquery.Table(messages_table_id)
        messages_table.external_data_configuration = external_config
        try:
            client.create_table(messages_table)
            print(f"- Created messages table {messages_table_id}")
            results['created'].append({
                'table_id': messages_table_id
            })
        except Conflict:
            print(f"- Messages table {messages_table_id} already exists")

    # Process each unique device_id/message combination
    for prefix in prefixes:
        device_id, message = prefix.split('/')
        table_id = f"{project_id}.{dataset_id}.tbl_{device_id}_{message}"
        
        # Define source URI
        source_uris = [f"gs://{bucket_output_name}/{prefix}/*"]
        
        # Create external table in BigQuery
        external_config = bigquery.ExternalConfig('PARQUET')
        external_config.source_uris = source_uris
        external_config.autodetect = True
        external_config.ignore_unknown_values = True
        
        table = bigquery.Table(table_id)
        table.external_data_configuration = external_config
        
        try:
            client.create_table(table)
            print(f"- Created table {table_id}")
            results['created'].append({
                'table_id': table_id
            })
        except Conflict:
            print(f"- Table {table_id} already exists")

    print("\nFinished creating external tables for all device and message combinations, including messages and devicemeta tables.")
    
    
    # Return the response for API consumers
    return {
        'status': 'success',
        'message': 'BigQuery tables mapped successfully',
        'results': results
    }


