
#!/bin/bash
# Request parameters from the user
echo "Please provide the following information:"
read -p "Project ID (textual name): " PROJECT
read -p "Location (e.g. \"eu\"): " LOCATION
read -p "Dataset name: " DATASET
read -p "Connection name: " CONNECTION

if [ -z "$PROJECT" ] || [ -z "$DATASET" ] || [ -z "$CONNECTION" ] || [ -z "$LOCATION" ]; then
  echo "Error: All parameters are required."
  exit 1
fi

# Create dataset
bq --location=$LOCATION mk --dataset $PROJECT:$DATASET

# Create connection
bq mk --connection --location=$LOCATION --project_id=$PROJECT --connection_type=CLOUD_RESOURCE $CONNECTION

# Grant Vertex AI User to the BQ service account
SERVICEACCOUNT=`bq show --connection $LOCATION.$CONNECTION | grep -oP '(?<="serviceAccountId": ")[^"]+'`
gcloud projects add-iam-policy-binding $PROJECT --member=serviceAccount:$SERVICEACCOUNT --role=roles/aiplatform.user

# Create model
echo "CREATE OR REPLACE MODEL \`$DATASET\`.GeminiFlash REMOTE WITH CONNECTION \`$LOCATION.$CONNECTION\` OPTIONS (endpoint = 'gemini-1.5-flash-001');" | bq query --use_legacy_sql=false

# Install stored functions & procedures
sed "s/\[DATASET\]/$DATASET/" generation.sql | bq query --use_legacy_sql=false
