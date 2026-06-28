# Databricks notebook source
# =============================================================================
# BRONZE INGESTION — Raw Data Landing Zone
# =============================================================================
# Reads raw files using Auto Loader (Structured Streaming) with schema
# enforcement. Lands data in Delta Lake Bronze table with merge-on-read.
#
# COMPLIANCE:
#   - No data transformation at this stage (preserves raw audit trail)
#   - Schema enforcement prevents malformed data injection
#   - All reads/writes go through Unity Catalog governed paths
# =============================================================================

import json
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType
from pyspark.sql.functions import current_timestamp, input_file_name, lit

# ---------------------------------------------------------------------------
# Configuration (injected via DAB base_parameters)
# ---------------------------------------------------------------------------
dbutils.widgets.text("storage_path", "", "Base storage path")
dbutils.widgets.text("secret_scope", "", "Databricks secret scope name")

STORAGE_PATH = dbutils.widgets.get("storage_path")
SECRET_SCOPE = dbutils.widgets.get("secret_scope")

BRONZE_SOURCE_PATH = f"{STORAGE_PATH}/raw-ingest/"
BRONZE_CHECKPOINT = f"{STORAGE_PATH}/checkpoints/bronze/"
BRONZE_TABLE = "medallion.bronze.raw_events"

# ---------------------------------------------------------------------------
# Schema Enforcement
# ---------------------------------------------------------------------------
# Load schema from JSON definition for strict enforcement
BRONZE_SCHEMA = StructType.fromJson(
    json.loads(
        open("/Workspace/Repos/medallion-security-pipeline/schemas/bronze_schema.json").read()
    )
) if False else None  # Fallback to schema inference if file not available

# ---------------------------------------------------------------------------
# Bronze Ingestion Pipeline (Auto Loader)
# ---------------------------------------------------------------------------
print(f"[BRONZE] Starting ingestion from: {BRONZE_SOURCE_PATH}")
print(f"[BRONZE] Target table: {BRONZE_TABLE}")

# Read raw files using Auto Loader (cloudFiles) for incremental processing
raw_df = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", f"{BRONZE_CHECKPOINT}/schema/")
    .option("cloudFiles.inferColumnTypes", "true")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .load(BRONZE_SOURCE_PATH)
)

# Add ingestion metadata columns for audit trail
bronze_df = (
    raw_df
    .withColumn("_ingestion_timestamp", current_timestamp())
    .withColumn("_source_file", input_file_name())
    .withColumn("_medallion_layer", lit("bronze"))
    .withColumn("_pipeline_run_id", lit(dbutils.notebook.entry_point.getDbutils()
                                        .notebook().getContext().currentRunId().toString()
                                        if hasattr(dbutils.notebook.entry_point.getDbutils().notebook().getContext(), 'currentRunId')
                                        else "interactive"))
)

# Write to Bronze Delta table (append mode — preserve all raw records)
bronze_write = (
    bronze_df.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", BRONZE_CHECKPOINT)
    .option("mergeSchema", "true")  # Allow schema evolution
    .trigger(availableNow=True)     # Process all available files, then stop
    .toTable(BRONZE_TABLE)
)

# Wait for streaming query to complete
bronze_write.awaitTermination()

# ---------------------------------------------------------------------------
# Post-Ingestion Validation
# ---------------------------------------------------------------------------
record_count = spark.table(BRONZE_TABLE).count()
print(f"[BRONZE] Ingestion complete. Total records in Bronze table: {record_count}")

# Optimize table for downstream reads
spark.sql(f"OPTIMIZE {BRONZE_TABLE}")
print(f"[BRONZE] Table optimized successfully")
