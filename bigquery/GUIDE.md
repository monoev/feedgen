# User's Guide

Below, you find step-by-step instructions on how to install and apply our BigQuery scripts to improve product feeds. Placeholders and examples are prefixed with "👉" and need to be replaced with the actual names before execution.

# Guide for setting up FeedGen - for new products

## 1. Deploy model & stored procedures

Download [generation.sql](./generation.sql) and [install.sh](./install.sh), execute the latter (in GCP: `bash install.sh`) and input the requested configuration. Alternatively, you can perform the following manually:
1. [Create a dataset](https://cloud.google.com/bigquery/docs/datasets#create-dataset). Use the chosen name instead of `[👉DATASET]` in the code below.
2. [Create a connection](https://cloud.google.com/bigquery/docs/generate-text-tutorial\#create\_a\_connection). Use the chosen name instead of `[👉CONNECTION]` in the code below.
4. [Grant](https://console.corp.google.com/iam-admin/iam) *Vertex AI User* to the connection's service account.
5. [Create a model](https://cloud.google.com/bigquery/docs/reference/standard-sql/bigqueryml-syntax-create-remote-model) `GeminiFlash` in your dataset. (You can find the needed command near the end of [install.sh](./install.sh).)
6. In [these scripts](generation.sql), replace all occurrences of `[DATASET]` with the actual one to be used, and execute them. This deploys the stored functions (building prompts) and procedures (using prompts).

⚠️ Note: Before deploying these functions, or as an improvement after initial testing, you may want to modify them so that the prompts reflect your preferences for the titles and descriptions in terms of length, tone and other aspects, perhaps even adapted to the product category at hand. To improve the output quality with languages other than English, the prompts might also be re-written in that language.

## 2. Create input raw table with latest import of product catalog
Selects the relevant fields, and combines the relevant data. In this case, it combines from one b2c and one b2b feed, but usually it will only be necessary to select from one.  
This creates the table InputRawLatestImport. If needed, you can also do some data cleaning in the select statements.

```sql 
CREATE OR REPLACE TABLE `[👉DATASET].InputRawLatestImport`
AS
SELECT * EXCEPT(row_num)
FROM (
  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY id) AS row_num
  FROM (
  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY id) AS row_num
  FROM (SELECT id, title, images, description, category, other_attribute_1, other_attribute_2 FROM `[👉DATASET].TableOfRawData1`
  UNION DISTINCT
  SELECT id, title, images, description, category, other_attribute_1, other_attribute_2
  FROM `[👉DATASET].TableOfRawData2`))
)
WHERE row_num = 1;
```
## 2. Filter raw data to only keep id's that have not yet been processed into `InputFiltered`

Selects all products from InputRawLatestImport that are not in the final export file with all products (ProductEnrichmentExport) so that only products that do not have an AI generated description and bulletpoints will be processed.

```sql
CREATE OR REPLACE TABLE `[👉DATASET].InputFiltered` AS(
SELECT * FROM `[👉DATASET].InputRawLatestImport` 
WHERE id NOT IN (SELECT 👉Id_Column_name from `ProductEnrichmentExport`));
```

## 3. Update `OriginalDescriptions` table for storing original human-written descriptions
Writes original descriptions of new projects to a separate table OriginalDescriptions this is in case the descriptions in the data will be overwritten by the AI generated descriptions, so that we have then for potential future re-generations of AI descriptions.

Create the table first with the following fields (one time operation)
```sql
CREATE OR REPLACE TABLE `[👉DATASET].OriginalDescriptions` (
  id STRING,
  description STRING,
  bulletpoints ARRAY<STRING>
);
```

Then insert the data of the fields being processed into `[👉DATASET].OriginalDescriptions`
```sql
INSERT INTO `[👉DATASET].OriginalDescriptions` (id, description, bulletpoints)
SELECT id, description, bulletpoints
FROM `[👉DATASET].InputFiltered` as input
WHERE NOT EXISTS (
    SELECT 1 
    FROM `[👉DATASET].OriginalDescriptions` od 
    WHERE od.id = input.id
);
```

## 4. Write image URLS to Cloud Storage
Python script to write all image URLs to a cloud storage bucket to be used for image description generation 

```python
from google.cloud import bigquery, storage
import pandas as pd

# BQ client
bq_client = bigquery.Client()
gcs_client = storage.Client()

# vars - BQ
project_id = "[👉PROJECT_ID]"
dataset_id = "[👉DATASET]"
table_id = "[👉TABLE]"
column_name = "[👉IMAGE_URL_COLUMN]"

# vars - cloud storage
bucket_name = "images_tsv_file"
tsv_filename = "image_urls_new_products.tsv"
gcs_path = f"gs://{bucket_name}/{tsv_filename}"

# query
query = f"""
SELECT {column_name}
FROM `{project_id}.{dataset_id}.{table_id}`
"""

# convert to df
query_job = bq_client.query(query)
df = query_job.to_dataframe()

# save locally

local_tsv = "/tmp/image_urls_new_products.tsv"
with open(local_tsv, "w") as f:
    f.write("TsvHttpData-1.0\n")
    df.to_csv(f, index=False, header=False, sep="\t")

# upload to cloud storage

bucket = gcs_client.bucket(bucket_name)
blob = bucket.blob(tsv_filename)
blob.upload_from_filename(local_tsv)

print(f"TSV file uploaded to {gcs_path}")
```

## 5. Create Image Transfer Job - Only need to run when generating descriptions for the first time
Create image transfer job 
```shell 
gcloud transfer jobs create \
  gs://SOURCE_BUCKET_NAME gs://DESTINATION_BUCKET_NAME \
  --do-not-run \
  --overwrite-when=different
```

## 6. Trigger Image Transfer Job
Python script to trigger the transfer job that fetches all images from the url list generated in step 5. 

```python
!pip install --upgrade google-cloud-storage-transfer
from google.cloud import storage_transfer
from google.protobuf import timestamp_pb2
import datetime

# vars
project_id = "[👉PROJECT_ID]"
job_name = "[👉TRANSFER_JOB_ID]"

def trigger_transfer_job(project_id, job_name):
    try:
        client = storage_transfer.StorageTransferServiceClient()

        # Set the start time to now
        now = datetime.datetime.utcnow()
        start_time = timestamp_pb2.Timestamp()
        start_time.FromDatetime(now)

        # Request to run the existing job
        response = client.run_transfer_job(
            {
                "job_name": f"transferJobs/{job_name}",
                "project_id": {project_id},
            }
        )

        print(f"Triggered transfer job: {response}")
    except Exception as e:
        print(f"Error triggering transfer job: {e}")

trigger_transfer_job(project_id, job_name)
```
## 7. Create Image Object Table
This sql query creates the object table linked to the images stored in cloud storage. 

```sql
CREATE OR REPLACE EXTERNAL TABLE `[👉DATASET].ImageObjectTable`
WITH CONNECTION `[👉PROJECT_ID].eu.[👉CONNECTION]`
OPTIONS(
  object_metadata = 'SIMPLE',
  uris = ['BUCKET_NAME'],
  max_staleness = INTERVAL 7 DAY,
  metadata_cache_mode = 'AUTOMATIC');
```
## 8. Trigger image description generation 
This query triggers image descriptions to be generated for products, this can be used when only a few descriptions need to be generated.
```sql
CREATE OR REPLACE TABLE `[👉DATASET]`.InputFilteredImagesNew AS
SELECT uri, TRIM(ml_generate_text_llm_result) AS description
FROM
  ML.GENERATE_TEXT(
    MODEL `[👉DATASET]`.GeminiFlash2,
    TABLE `[👉DATASET]`.ImageObjectTable,
    STRUCT(
      'Provide a description in Norwegian of the product shown in this image, including any important visible text on the product. The description should focus on essential details like color and other clear characteristics that are visible in the image. Do not infer the product’s size based on visual cues. Do not include introductory phrases such as ‘Here is a description of the product’ or statements like ‘There is no visible text on the product.’ If no description can be generated, return an empty response.' AS prompt,
      0 AS temperature,
      1024 AS max_output_tokens,
      TRUE AS flatten_json_output));
```

When generating descriptions for MANY products, this code should be used. Here the script used batching and increased number of workers to handle tens of thousands of products. 
```python
from concurrent.futures import ThreadPoolExecutor, as_completed
from google.cloud import bigquery
import math

# Initialize BigQuery client
client = bigquery.Client()

# Clear the table before starting
client.query("TRUNCATE TABLE `[👉DATASET]`.InputFilteredImagesNew;").result()
print("Table cleared.")

# Configuration
batch_size = 1000
max_workers = 2

# Get total rows
total_rows_query = "SELECT COUNT(*) as total FROM `[👉DATASET]`.images"
total_rows = client.query(total_rows_query).result().to_dataframe().iloc[0]['total']
print(total_rows)
total_batches = math.ceil(total_rows / batch_size)
print("Batch size:",batch_size)
print("Total batches:",total_batches)

# Query template
query_template = """
INSERT INTO `[👉DATASET]`.InputFilteredImagesNew (uri, description)
SELECT uri, TRIM(ml_generate_text_llm_result) AS description
FROM
  ML.GENERATE_TEXT(
    MODEL `[👉DATASET]`.GeminiFlash2,
    (
      SELECT * FROM `[👉DATASET]`.images
      LIMIT {batch_size} OFFSET {offset}
    ),
    STRUCT(
      '‹Provide a description in Norwegian of the product shown in this image, including any important visible text on the product. The description should focus on essential details like color and other clear characteristics that are visible in the image. Do not infer the product’s size based on visual cues. Do not include introductory phrases such as ‘Here is a description of the product’ or statements like ‘There is no visible text on the product.’ If no description can be generated, return an empty response.' AS prompt,
      0 AS temperature,
      1024 AS max_output_tokens,
      TRUE AS flatten_json_output)
  );
"""

def run_batch(batch_number):
    """Runs a single batch query with the given offset."""
    offset = batch_number * batch_size
    query = query_template.format(batch_size=batch_size, offset=offset)
    job = client.query(query)
    job.result()  # Wait for completion
    return f"Batch {batch_number + 1}/{total_batches} completed."

# Run batches in parallel
with ThreadPoolExecutor(max_workers=max_workers) as executor:
    futures = [executor.submit(run_batch, batch) for batch in range(total_batches)]

    for future in as_completed(futures):
        print(future.result())
        
```
## 9. Append new image descriptions to inputFilteredImages
This query appends all new image descriptions to the inputFilteredImages table. 
```sql 
INSERT INTO `[👉DATASET].InputFilteredImages` 
SELECT * FROM `[👉DATASET].InputFilteredImagesNew` AS src
WHERE NOT EXISTS (
    SELECT 1 FROM `[👉DATASET].InputFilteredImages` AS tgt
    WHERE src.id = tgt.id
);
```
## 10. Prepare input processing table
This query combines the cleaned data with the generated image descriptions to create the table used for the InputProcessing-table used for description and bulletpoint generation. 

The main procedures expect the data to be in a table `InputProcessing`, which needs a field `id` (with a unique identifier for each product) along with the feed's actual data fields. All those other fields are going to be used for the generation of titles and descriptions, so what should not be used should not be in `InputProcessing`.


```sql
CREATE OR REPLACE TABLE `[👉DATASET]`.InputProcessing AS
SELECT
    F.*,
    I.description AS image_description
FROM `[👉DATASET]`.InputFiltered AS F
LEFT JOIN `[👉DATASET]`.InputFilteredImagesNew AS I
ON REGEXP_EXTRACT(F.images, r'([^/]+)\.jpg$') = REGEXP_EXTRACT(I.uri, r'([^/]+)\.jpg$');
```

## 11. Create empty output table 
This query generates an empty table to be filled with generated descriptions. The trigger functions will use these id's in the procedures, and write the generated descriptions and bulletpoints to this table. 
```sql 
CREATE OR REPLACE TABLE `[👉DATASET]`.Output AS
SELECT
  id,
  CAST(NULL AS STRING) AS bullets,
  CAST(NULL AS STRING) AS description,
  0 AS tries
FROM `[👉DATASET]`.InputFiltered;
```
The `tries` field addresses the fact that the generation of titles or descriptions may fail, usually due to Vertex AI's "[safety filters](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/configure-safety-attributes)". The field counts the number of re-generation attempts, which the generating procedures use to limit repeated failures – currently set to 2 retries in the procedure definition.


## 12. Create/update example table
Run to make sure the example table contains the most recent data from the connected to a sheet. 

If you are generating for the first time, you need to first create a table called _ExampleDescriptionsAndBullets_ connected to a Google sheet. This table needs to contain the following fields: __id, description and bullets.__ 
```sql
CREATE OR REPLACE TABLE `[👉DATASET]`.ExampleProducts AS
SELECT
  D.id,
  D.bullets,
  D.description,
  TO_JSON_STRING((SELECT AS STRUCT * EXCEPT(id) FROM UNNEST([I]))) AS properties
FROM `[👉DATASET]`.ExampleDescriptionsAndBullets AS D
INNER JOIN `[👉DATASET]`.InputProcessing AS I USING (id);
```

## 13. Trigger generation of titles & descriptions

Once the input data has been made available, the actual processing can start with a one-liner each for titles and descriptions, looping through the records by themselves:

``CALL `[👉DATASET]`.BatchedUpdateTitles(ITEMS_PER_PROMPT, "Norwegian", PARTS, PART, IDS);``

``CALL `[👉DATASET]`.BatchedUpdateDescriptions(ITEMS_PER_PROMPT, "Norwegian", PARTS, PART, IDS);``

These procedures expect the following parameters:

* `ITEMS_PER_PROMPT`: The number of records to group into a single LLM request to increase throughput – see [Performance](./README.md#performance) for thoughts on reasonable upper limits. For efficiency reasons, this should be a divisor of the number of products processed per loop (hard-coded, currently set to 600 in [here](generation.sql)).
* `LANGUAGE`: The language in which to generate the texts, as an English word.
* `PARTS`: Together with the next parameter, this allows the parallel processing of different parts of the feed. This parameter denotes the number of parts. Consider the [maximally allowed](https://cloud.google.com/bigquery/quotas\#cloud\_ai\_service\_functions) parallelisation for `ML.GENERATE_TEXT` as well as any other queries that you may be running with that function. Use NULL if you don't want any such partitioning.
* `PART`: This denotes which of the parts (0 up to `PARTS`–1) to compute.
* `IDS`: This is NULL for the default scaled execution, but if specific items' texts are to be (re-)generated, their item IDs can be provided in this array.

Here are two example calls, one with partitioning, one without:
```
CALL `[👉DATASET]`.BatchedUpdateDescriptions(10, 'Norwegian', 4, 2, NULL);
CALL `[👉DATASET]`.BatchedUpdateTitles(15, 'Norwegian', NULL, NULL, NULL);
```

⚠️ Note: In case the table `Output` has undesired data from a previous execution, it should be re-initialised with the SQL code in step 11. 

## 14. Check results

The generating procedures write their results into the table `Output` in the same dataset, where they can be assessed for quality – manually, using [similarity measures](./example_check.sql), or with tailor-made prompts.

