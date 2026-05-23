# Data Engineer Comprehensive Guide — Part 2
## Apache Beam · Apache Airflow

---

# 5. Apache Beam — Beginner-Friendly Deep Dive

> [!NOTE]
> Apache Beam is the **processing engine**. It answers: "HOW do I transform my data?"

## 5.1 What Is Apache Beam?

Think of Beam as a **universal translator for data pipelines**. You write your pipeline ONCE, and run it on different engines (Dataflow, Spark, Flink).

```
                    Write Once
                       │
              ┌────────┴────────┐
              │   Apache Beam   │
              │   (Unified API) │
              └────────┬────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │ Dataflow │ │  Spark   │ │  Flink   │
    │ (GCP)    │ │ Runner   │ │ Runner   │
    └──────────┘ └──────────┘ └──────────┘
```

**Key idea**: Beam separates the **what** (your pipeline logic) from the **where** (execution engine).

## 5.2 Core Concepts

### PCollection
The fundamental data structure — an immutable, distributed dataset.

```python
# A PCollection is like a distributed list
# It can be bounded (batch) or unbounded (streaming)
lines = p | 'ReadFile' >> beam.io.ReadFromText('input.txt')
# 'lines' is a PCollection of strings
```

### PTransform
Operations that transform PCollections.

```python
# Map: apply function to each element
upper = lines | 'ToUpper' >> beam.Map(str.upper)

# Filter: keep elements matching condition
long = lines | 'FilterLong' >> beam.Filter(lambda x: len(x) > 10)

# FlatMap: one-to-many transformation
words = lines | 'Split' >> beam.FlatMap(lambda line: line.split())

# GroupByKey: group values by key
grouped = pairs | 'Group' >> beam.GroupByKey()

# Combine: aggregate (sum, count, mean)
total = numbers | 'Sum' >> beam.CombineGlobally(sum)
```

### Pipeline
The container that holds the entire workflow.

```python
import apache_beam as beam

with beam.Pipeline() as p:
    (
        p
        | 'Read' >> beam.io.ReadFromText('gs://bucket/input.csv')
        | 'Parse' >> beam.Map(parse_csv_line)
        | 'Filter' >> beam.Filter(lambda r: r['amount'] > 100)
        | 'Format' >> beam.Map(format_for_bq)
        | 'Write' >> beam.io.WriteToBigQuery('project:dataset.table')
    )
```

## 5.3 The Pipe Operator (`|`)

Beam uses `|` to chain transforms. The string before `>>` is just a label.

```python
# These are equivalent:
result = input | 'StepName' >> SomeTransform()

# Read this as: input PIPE through StepName
```

## 5.4 Batch vs Streaming

```python
# BATCH: Read from file (bounded PCollection)
with beam.Pipeline(options=batch_options) as p:
    p | beam.io.ReadFromText('gs://bucket/data.csv')
      | beam.Map(process)
      | beam.io.WriteToText('gs://bucket/output')

# STREAMING: Read from Pub/Sub (unbounded PCollection)
with beam.Pipeline(options=streaming_options) as p:
    p | beam.io.ReadFromPubSub(topic='projects/proj/topics/events')
      | beam.Map(process)
      | beam.io.WriteToBigQuery('project:dataset.table')
```

## 5.5 Windowing (Streaming Concept)

Since streaming data never ends, you need **windows** to group data for aggregation.

```
Time →  |-------|-------|-------|
        Window1  Window2  Window3

Fixed Windows (tumbling): non-overlapping, fixed-size
  |  0-5min  |  5-10min  | 10-15min |

Sliding Windows: overlapping
  |  0-5min  |
     |  2-7min  |
        |  4-9min  |

Session Windows: gap-based per key
  User A: |--events--|  (gap > 10min)  |--events--|
  User B: |------events------|
```

```python
from apache_beam import window

# Fixed 5-minute windows
windowed = (
    events
    | 'Window' >> beam.WindowInto(window.FixedWindows(5 * 60))
    | 'Count' >> beam.CombineGlobally(beam.combiners.CountCombineFn())
)
```

## 5.6 Watermarks & Late Data

- **Watermark**: Beam's estimate of "all data up to time T has arrived"
- **Late data**: Data arriving after the watermark has passed
- **Allowed lateness**: How long to keep windows open for late arrivals

```python
windowed = (
    events
    | beam.WindowInto(
        window.FixedWindows(60),
        trigger=trigger.AfterWatermark(
            early=trigger.AfterProcessingTime(30),  # Emit early results
            late=trigger.AfterCount(1)               # Emit on each late element
        ),
        allowed_lateness=3600,           # Accept data up to 1 hour late
        accumulation_mode=trigger.AccumulationMode.ACCUMULATING
    )
)
```

## 5.7 Complete Real-World Pipeline

```python
import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
import json

class ParseEvent(beam.DoFn):
    """Parse JSON string into dict, handle errors."""
    def process(self, element):
        try:
            record = json.loads(element)
            if record.get('event_type') and record.get('user_id'):
                yield record
            else:
                yield beam.pvalue.TaggedOutput('invalid', element)
        except json.JSONDecodeError:
            yield beam.pvalue.TaggedOutput('invalid', element)

class EnrichWithUserData(beam.DoFn):
    """Side input: join with user dimension table."""
    def process(self, event, user_lookup):
        user_id = event['user_id']
        user_info = user_lookup.get(user_id, {})
        event['user_name'] = user_info.get('name', 'Unknown')
        event['user_tier'] = user_info.get('tier', 'free')
        yield event

def run():
    options = PipelineOptions([
        '--runner=DataflowRunner',
        '--project=my-gcp-project',
        '--region=us-central1',
        '--temp_location=gs://my-bucket/temp',
        '--streaming'
    ])

    with beam.Pipeline(options=options) as p:
        # Side input: user lookup table
        users = (
            p
            | 'ReadUsers' >> beam.io.ReadFromBigQuery(
                query='SELECT user_id, name, tier FROM `project.dataset.users`',
                use_standard_sql=True
            )
            | 'ToDict' >> beam.Map(lambda r: (r['user_id'], r))
        )
        user_dict = beam.pvalue.AsDict(users)

        # Main pipeline
        results = (
            p
            | 'ReadKafka' >> beam.io.ReadFromPubSub(
                topic='projects/my-project/topics/user-events'
            )
            | 'Decode' >> beam.Map(lambda x: x.decode('utf-8'))
            | 'Parse' >> beam.ParDo(ParseEvent())
                          .with_outputs('invalid', main='valid')
        )

        # Process valid events
        (
            results['valid']
            | 'Enrich' >> beam.ParDo(EnrichWithUserData(), user_dict)
            | 'Window' >> beam.WindowInto(
                beam.window.FixedWindows(300)  # 5-minute windows
            )
            | 'WriteBQ' >> beam.io.WriteToBigQuery(
                'project:dataset.enriched_events',
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND
            )
        )

        # Handle invalid events (dead letter)
        (
            results['invalid']
            | 'WriteErrors' >> beam.io.WriteToText(
                'gs://my-bucket/errors/invalid_events'
            )
        )

if __name__ == '__main__':
    run()
```

## 5.8 Beam on GCP = Dataflow

| Feature | Dataflow Advantage |
|---|---|
| **Auto-scaling** | Workers scale up/down based on backlog |
| **Streaming Engine** | Offloads windowing state from workers |
| **Flex Templates** | Package pipelines as container images |
| **Snapshots** | Save pipeline state, restart from snapshot |
| **Monitoring** | Built-in job monitoring in GCP Console |

## 5.9 Beam Interview Q&A

**Q: ParDo vs Map?**
A: `Map` applies a function returning one output per input. `ParDo` uses a `DoFn` class and can emit zero, one, or many outputs per input. Use `ParDo` for complex logic, side inputs/outputs.

**Q: What's a Side Input?**
A: Additional data available to every worker (e.g., a lookup table). Broadcast to all workers as a read-only view.

**Q: How does Beam handle exactly-once in streaming?**
A: Dataflow runner provides exactly-once via checkpointing and deduplication of records. It assigns unique IDs and deduplicates at shuffle boundaries.

---

# 6. Apache Airflow — Beginner-Friendly Deep Dive

> [!NOTE]
> Airflow is the **orchestrator**. It answers: "WHEN and in what ORDER should my pipelines run?"

## 6.1 What Is Airflow?

Airflow is a **workflow scheduler**. It does NOT process data itself — it tells OTHER systems when to run.

```
Airflow says:
  "At 2 AM daily:
    1. First, extract data from the API
    2. Then, run the Beam/Dataflow pipeline
    3. Then, validate the data in BigQuery
    4. Finally, send a Slack notification"
```

**Analogy**: Airflow is like a **movie director** — it doesn't act, but tells actors (Dataflow, BigQuery, Spark) when and what to do.

## 6.2 Core Concepts

### DAG (Directed Acyclic Graph)
A DAG defines your workflow — the tasks and their dependencies.

```
       extract_api
           │
           ▼
     transform_data
       │         │
       ▼         ▼
  load_to_bq   load_to_gcs
       │         │
       ▼         ▼
     validate_data
           │
           ▼
    send_notification
```

"Directed" = has a direction (A→B). "Acyclic" = no loops (A→B→A is forbidden).

### Operators
Pre-built task templates. Each operator = one task in your DAG.

| Operator | What It Does |
|---|---|
| `PythonOperator` | Run a Python function |
| `BashOperator` | Run a shell command |
| `BigQueryInsertJobOperator` | Run a BigQuery query |
| `DataflowStartPythonJobOperator` | Launch a Beam/Dataflow job |
| `GCSToGCSOperator` | Copy files in GCS |
| `KubernetesPodOperator` | Run a container in Kubernetes |
| `EmailOperator` | Send an email |
| `SlackWebhookOperator` | Send a Slack message |

### Sensors
Special operators that **wait** for a condition.

| Sensor | Waits For |
|---|---|
| `GCSObjectExistenceSensor` | A file to appear in GCS |
| `BigQueryTableExistenceSensor` | A table to exist in BQ |
| `ExternalTaskSensor` | Another DAG's task to complete |
| `HttpSensor` | An HTTP endpoint to return 200 |

### Other Key Concepts

| Concept | Explanation |
|---|---|
| **Task Instance** | A specific run of a task (DAG + Task + execution_date) |
| **XCom** | Cross-communication — pass small data between tasks |
| **Connections** | Stored credentials for external systems (GCP, DBs) |
| **Variables** | Global config values (e.g., env=prod, email=team@co.com) |
| **Pools** | Limit concurrency (e.g., max 5 BigQuery jobs at once) |
| **execution_date** | The logical date the DAG run represents (not when it actually runs) |
| **Backfill** | Run a DAG for past dates to catch up on missed runs |

## 6.3 Your First DAG

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.providers.google.cloud.sensors.gcs import GCSObjectExistenceSensor
from datetime import datetime, timedelta

# Default arguments for all tasks
default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'email': ['data-team@company.com'],
    'email_on_failure': True,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
with DAG(
    dag_id='daily_sales_pipeline',
    default_args=default_args,
    description='Daily sales data ETL pipeline',
    schedule_interval='0 2 * * *',   # Run at 2 AM daily
    start_date=datetime(2026, 1, 1),
    catchup=False,                    # Don't backfill past dates
    tags=['sales', 'etl', 'production'],
) as dag:

    # Task 1: Wait for source file
    wait_for_file = GCSObjectExistenceSensor(
        task_id='wait_for_source_file',
        bucket='raw-data-bucket',
        object='sales/{{ ds }}/sales_data.csv',  # ds = execution date
        timeout=3600,        # Wait up to 1 hour
        poke_interval=60,   # Check every minute
    )

    # Task 2: Extract and validate
    def extract_and_validate(**context):
        from google.cloud import storage
        ds = context['ds']  # execution date as YYYY-MM-DD
        client = storage.Client()
        bucket = client.bucket('raw-data-bucket')
        blob = bucket.blob(f'sales/{ds}/sales_data.csv')
        content = blob.download_as_text()
        row_count = len(content.strip().split('\n')) - 1  # minus header

        if row_count < 100:
            raise ValueError(f"Only {row_count} rows — expected at least 100")

        # Pass row count to downstream tasks via XCom
        context['ti'].xcom_push(key='row_count', value=row_count)
        print(f"✅ Validated {row_count} rows for {ds}")

    validate = PythonOperator(
        task_id='extract_and_validate',
        python_callable=extract_and_validate,
    )

    # Task 3: Load to BigQuery
    load_to_bq = BigQueryInsertJobOperator(
        task_id='load_to_bigquery',
        configuration={
            'query': {
                'query': """
                    INSERT INTO `project.dataset.sales`
                    SELECT *
                    FROM `project.dataset.raw_sales_staging`
                    WHERE DATE(sale_date) = '{{ ds }}'
                """,
                'useLegacySql': False,
            }
        },
    )

    # Task 4: Data quality check
    quality_check = BigQueryInsertJobOperator(
        task_id='data_quality_check',
        configuration={
            'query': {
                'query': """
                    SELECT
                        COUNT(*) as total_rows,
                        COUNT(DISTINCT order_id) as unique_orders,
                        SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) as null_amounts
                    FROM `project.dataset.sales`
                    WHERE DATE(sale_date) = '{{ ds }}'
                    HAVING null_amounts > 0 OR total_rows = 0
                """,
                'useLegacySql': False,
            }
        },
    )

    # Task 5: Notify
    def send_notification(**context):
        row_count = context['ti'].xcom_pull(
            task_ids='extract_and_validate', key='row_count'
        )
        print(f"📧 Pipeline complete for {context['ds']}: {row_count} rows loaded")

    notify = PythonOperator(
        task_id='send_notification',
        python_callable=send_notification,
    )

    # Define dependencies (execution order)
    wait_for_file >> validate >> load_to_bq >> quality_check >> notify
```

## 6.4 Jinja Templating in Airflow

Airflow uses Jinja2 templates to inject runtime variables.

| Template Variable | Value | Example |
|---|---|---|
| `{{ ds }}` | Execution date | `2026-05-15` |
| `{{ ds_nodash }}` | Date without dashes | `20260515` |
| `{{ prev_ds }}` | Previous execution date | `2026-05-14` |
| `{{ ts }}` | Timestamp | `2026-05-15T02:00:00+00:00` |
| `{{ params.my_param }}` | Custom parameter | Any value you define |
| `{{ var.value.my_var }}` | Airflow Variable | Stored in Airflow metadata DB |

## 6.5 Advanced DAG Patterns

### Dynamic Task Generation
```python
tables = ['users', 'orders', 'products', 'payments']

for table in tables:
    extract = PythonOperator(
        task_id=f'extract_{table}',
        python_callable=extract_table,
        op_kwargs={'table_name': table},
    )
    load = PythonOperator(
        task_id=f'load_{table}',
        python_callable=load_to_bq,
        op_kwargs={'table_name': table},
    )
    extract >> load
```

### TaskGroups (Organize Related Tasks)
```python
from airflow.utils.task_group import TaskGroup

with TaskGroup('extract_phase') as extract_group:
    extract_api = PythonOperator(task_id='extract_api', ...)
    extract_db = PythonOperator(task_id='extract_db', ...)

with TaskGroup('transform_phase') as transform_group:
    clean = PythonOperator(task_id='clean_data', ...)
    enrich = PythonOperator(task_id='enrich_data', ...)
    clean >> enrich

extract_group >> transform_group
```

### Branching (Conditional Execution)
```python
from airflow.operators.python import BranchPythonOperator

def choose_branch(**context):
    ds = context['ds']
    day = datetime.strptime(ds, '%Y-%m-%d').weekday()
    if day < 5:  # Mon-Fri
        return 'weekday_processing'
    return 'weekend_processing'

branch = BranchPythonOperator(
    task_id='check_day_type',
    python_callable=choose_branch,
)

weekday = PythonOperator(task_id='weekday_processing', ...)
weekend = PythonOperator(task_id='weekend_processing', ...)

branch >> [weekday, weekend]
```

## 6.6 Airflow on GCP = Cloud Composer

| Feature | Benefit |
|---|---|
| **Managed Airflow** | No infra to manage (runs on GKE) |
| **Pre-installed GCP providers** | BigQuery, Dataflow, GCS operators ready |
| **Integrated IAM** | Uses GCP service accounts |
| **Monitoring** | Cloud Monitoring + Airflow UI |
| **Auto-upgrades** | Composer 2 handles Airflow version upgrades |

```
Cloud Composer Architecture:
┌─────────────────────────────────┐
│        Cloud Composer           │
│  ┌────────────────────────┐     │
│  │  GKE Cluster           │     │
│  │  ├── Airflow Webserver │     │
│  │  ├── Airflow Scheduler │     │
│  │  └── Airflow Workers   │     │
│  └────────────────────────┘     │
│  ┌────────────────────────┐     │
│  │  Cloud SQL (metadata)  │     │
│  └────────────────────────┘     │
│  ┌────────────────────────┐     │
│  │  GCS Bucket (DAGs)     │     │
│  └────────────────────────┘     │
└─────────────────────────────────┘
```

## 6.7 Airflow Interview Q&A

**Q: What's the difference between `schedule_interval` and `execution_date`?**
A: `schedule_interval` is how often the DAG runs (e.g., daily). `execution_date` is the **logical date** the run represents. A daily DAG scheduled at 2 AM on May 15 has `execution_date = May 14` (end of the data interval it processes).

**Q: How do you handle task failures?**
A: Use `retries` + `retry_delay` in default_args. Set `email_on_failure=True` for alerts. Use `on_failure_callback` for custom actions. For critical pipelines, set up SLA monitoring.

**Q: What's the difference between `depends_on_past` and `wait_for_downstream`?**
A: `depends_on_past=True` means a task won't run unless its **previous instance** succeeded. `wait_for_downstream=True` adds the condition that the previous instance's **downstream tasks** must also have succeeded.

**Q: How do you pass data between tasks?**
A: Use **XCom** for small data (< 48KB). For large data, write to GCS/BigQuery and pass the path via XCom.

**Q: What's the difference between `BranchPythonOperator` and `ShortCircuitOperator`?**
A: `BranchPythonOperator` chooses which downstream task(s) to run. `ShortCircuitOperator` either continues the entire downstream chain or skips everything.

---

*Continue to Part 3 for Kubernetes, End-to-End Architecture, and Interview Scenarios →*
