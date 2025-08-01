# Prerequisites 
Review the README.md, deploy_bigquery.sh, deploy_mdftoparquet.sh, bigquery/ contents and mdftoparquet/ contents.

# Task 1
We want to update the mdftoparquet deployment so that it deploys an additional cloud function. The scripts for this can be stored in modules/cloud_function_backlog. The deployment details for this cloud function should be similar to the bigquery/modules/cloud_function. 

The user must be able to provide the name of this function zip when deploying. The zip will be stored in the input bucket - similar to how it's done when deploying the mdftoparquet/ and bigquery/ cloud functions.

In the deploy_mdftoparquet.sh script, the user should be able to provide the zip object path via a zip_backlog parameter. The README.md should also be updated.

The permissions for the function should be the same as for the mdftoparquet/modules/cloud_function, so do not create new separate users etc, but reuse those already created. 

