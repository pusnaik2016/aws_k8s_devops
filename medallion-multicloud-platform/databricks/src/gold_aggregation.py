# Databricks notebook source
# =============================================================================
# GOLD AGGREGATION — Business-Level Analytics Aggregates
# =============================================================================
# Reads Silver Delta table and produces business aggregates optimized for
# analytics consumption. Applies Z-ORDER optimization for query performance.
# =============================================================================

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, avg, min as spark_min,
    max as spark_max, current_timestamp, lit, date_trunc, countDistinct
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
dbutils.widgets.text("storage_path", "", "Base storage path")
dbutils.widgets.text("secret_scope", "", "Databricks secret scope name")

STORAGE_PATH = dbutils.widgets.get("storage_path")
SECRET_SCOPE = dbutils.widgets.get("secret_scope")

SILVER_TABLE = "medallion.silver.cleansed_events"
GOLD_SUMMARY_TABLE = "medallion.gold.event_summary"
GOLD_DAILY_TABLE = "medallion.gold.daily_aggregates"
GOLD_METRICS_TABLE = "medallion.gold.pipeline_metrics"

# ---------------------------------------------------------------------------
# Gold Aggregation Pipeline
# ---------------------------------------------------------------------------
print(f"[GOLD] Reading from Silver table: {SILVER_TABLE}")

silver_df = spark.table(SILVER_TABLE)
total_silver_records = silver_df.count()
print(f"[GOLD] Silver table contains {total_silver_records} records")

# -------------------------------------------------------------------------
# Aggregate 1: Event Summary (overall statistics)
# -------------------------------------------------------------------------
summary_df = (
    silver_df
    .agg(
        count("*").alias("total_records"),
        countDistinct("_record_hash").alias("unique_records"),
        spark_min("_ingestion_timestamp").alias("earliest_ingestion"),
        spark_max("_ingestion_timestamp").alias("latest_ingestion"),
        spark_min("_transformation_timestamp").alias("earliest_transform"),
        spark_max("_transformation_timestamp").alias("latest_transform"),
    )
    .withColumn("_medallion_layer", lit("gold"))
    .withColumn("_aggregation_timestamp", current_timestamp())
    .withColumn("_aggregate_type", lit("event_summary"))
)

print("[GOLD] Writing event summary aggregate")
summary_df.write \
    .format("delta") \
    .mode("overwrite") \
    .saveAsTable(GOLD_SUMMARY_TABLE)

# -------------------------------------------------------------------------
# Aggregate 2: Daily Aggregates (time-series for dashboards)
# -------------------------------------------------------------------------
if "_ingestion_timestamp" in silver_df.columns:
    daily_df = (
        silver_df
        .withColumn("date", date_trunc("day", col("_ingestion_timestamp")))
        .groupBy("date")
        .agg(
            count("*").alias("record_count"),
            countDistinct("_source_file").alias("source_file_count"),
            countDistinct("_record_hash").alias("unique_records"),
        )
        .orderBy("date")
        .withColumn("_medallion_layer", lit("gold"))
        .withColumn("_aggregation_timestamp", current_timestamp())
    )

    print("[GOLD] Writing daily aggregates")
    daily_df.write \
        .format("delta") \
        .mode("overwrite") \
        .saveAsTable(GOLD_DAILY_TABLE)

# -------------------------------------------------------------------------
# Aggregate 3: Pipeline Metrics (for compliance KPI dashboard)
# -------------------------------------------------------------------------
metrics_df = spark.createDataFrame([{
    "metric_timestamp": str(current_timestamp()),
    "bronze_record_count": spark.table("medallion.bronze.raw_events").count(),
    "silver_record_count": total_silver_records,
    "gold_summary_generated": True,
    "pipeline_status": "SUCCESS",
    "medallion_layer": "gold",
}])

metrics_df.write \
    .format("delta") \
    .mode("append") \
    .saveAsTable(GOLD_METRICS_TABLE)

# -------------------------------------------------------------------------
# Post-Aggregation Optimization
# -------------------------------------------------------------------------
print("[GOLD] Optimizing Gold tables...")
spark.sql(f"OPTIMIZE {GOLD_SUMMARY_TABLE}")
spark.sql(f"OPTIMIZE {GOLD_DAILY_TABLE}")

# Z-ORDER for query performance on common filter columns
if "_ingestion_timestamp" in silver_df.columns:
    spark.sql(f"OPTIMIZE {GOLD_DAILY_TABLE} ZORDER BY (date)")

print(f"[GOLD] Aggregation complete. Pipeline metrics recorded.")
print(f"[GOLD] Tables produced: {GOLD_SUMMARY_TABLE}, {GOLD_DAILY_TABLE}, {GOLD_METRICS_TABLE}")
