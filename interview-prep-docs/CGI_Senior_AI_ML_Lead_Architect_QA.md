# CGI – Senior AI/ML Lead / Architect
## Detailed Interview Questionnaire & Answers (AWS Focused)
### Experience: 8–12 Years | Category: Software Development / Engineering

---

> **Sections Covered:**
> 1. ML Lifecycle & Architecture
> 2. AWS AI/ML Ecosystem
> 3. MLOps & CI/CD
> 4. Kubernetes & GPU Workloads
> 5. Data Engineering & Pipelines
> 6. LLMs & Generative AI
> 7. Responsible AI & Governance
> 8. Leadership & Consulting
> 9. Scenario / Case Study Questions
> 10. Behavioral / Situational Questions

---

## 1. ML Lifecycle & Architecture

---

### Q1. Walk us through how you design an end-to-end ML solution from business problem definition to production monitoring.

**Answer:**

End-to-end ML solution design follows a structured lifecycle:

**Phase 1 – Business Problem Definition**
- Engage stakeholders to translate the business problem into an ML problem statement (classification, regression, ranking, generation, etc.).
- Define success metrics: business KPIs (revenue lift, cost reduction) and ML metrics (accuracy, AUC, F1, RMSE).
- Conduct feasibility assessment: data availability, labeling cost, latency SLAs, budget.

**Phase 2 – Data Engineering**
- Data discovery and profiling using tools like AWS Glue Data Catalog, Athena.
- Data quality checks: completeness, consistency, distributions using Great Expectations or Deequ (AWS).
- Feature engineering pipeline using Apache Spark on AWS EMR or AWS Glue jobs.
- Store features in Amazon SageMaker Feature Store for reuse.

**Phase 3 – Experimentation**
- Baseline model using simple heuristics to set a floor.
- Iterative experiments tracked in MLflow or SageMaker Experiments.
- Hyperparameter tuning using SageMaker Automatic Model Tuning (Bayesian / HyperBand).
- Model interpretability: SHAP values, LIME, SageMaker Clarify.

**Phase 4 – Training at Scale**
- Distributed training on SageMaker with data parallelism (Horovod) or model parallelism (SageMaker Model Parallel).
- GPU cluster training using p3/p4d/p5 instance families.
- Model registry: SageMaker Model Registry with versioning and approval workflows.

**Phase 5 – Deployment**
- Real-time inference: SageMaker Endpoint with autoscaling.
- Batch inference: SageMaker Batch Transform.
- Async inference for long-running predictions: SageMaker Async Inference.
- Multi-model endpoints for cost optimization.
- A/B testing and canary deployments using SageMaker traffic splitting.

**Phase 6 – Monitoring**
- SageMaker Model Monitor: data drift, concept drift, bias drift, explainability drift.
- Custom CloudWatch dashboards for latency, throughput, error rates.
- Automated retraining triggers based on drift thresholds via EventBridge + Step Functions.

---

### Q2. How do you approach model selection for a new ML problem?

**Answer:**

Model selection is a multi-criteria decision:

1. **Problem type**: Classification → Logistic Regression, XGBoost, Neural Nets; NLP → Transformers; Time-series → LSTM, Prophet, TFT.
2. **Data size**: Small data → simpler models with regularization; large data → deep learning.
3. **Latency SLA**: Sub-10ms → shallow models or optimized neural nets (TensorRT); relaxed → complex ensembles.
4. **Interpretability requirement**: Regulated industry → logistic regression, decision trees, SHAP-explained models.
5. **Baseline first**: Always start with XGBoost or Logistic Regression as baselines before investing in deep learning.
6. **AutoML**: Use SageMaker Autopilot or AWS AutoML for rapid benchmarking.
7. **Transfer learning**: Leverage pre-trained models (HuggingFace, Amazon Titan) for NLP/CV tasks to reduce training cost and data requirements.
8. **Cost vs. accuracy trade-off**: Ensemble methods improve accuracy but increase inference cost.

---

### Q3. Explain the concept of feature stores and their importance in enterprise ML.

**Answer:**

A **Feature Store** is a centralized repository for storing, discovering, and serving ML features consistently across training and inference.

**Key components:**
- **Offline store**: Historical features stored in S3 / Parquet for training (batch).
- **Online store**: Low-latency feature retrieval (sub-millisecond) for real-time inference using DynamoDB or Redis.
- **Feature registry**: Metadata, lineage, versioning.

**AWS Implementation – SageMaker Feature Store:**
```python
import boto3
import sagemaker
from sagemaker.feature_store.feature_group import FeatureGroup

feature_group = FeatureGroup(
    name="customer-transaction-features",
    sagemaker_session=sagemaker_session
)
feature_group.ingest(
    data_frame=df,
    max_workers=3,
    wait=True
)
```

**Importance:**
- **Training-serving skew elimination**: Same features computed once, reused everywhere.
- **Feature reuse**: Teams discover and reuse features, reducing duplication.
- **Point-in-time correctness**: Historical feature retrieval prevents data leakage.
- **Governance**: Lineage tracking for audit and compliance.
- **Productivity**: Reduces feature engineering time by 30–50% in large organizations.

---

### Q4. How do you handle class imbalance in production ML systems?

**Answer:**

**At data level:**
- **Oversampling**: SMOTE (Synthetic Minority Oversampling Technique).
- **Undersampling**: Random undersampling of majority class.
- **Data augmentation**: For image/text data.

**At algorithm level:**
- `class_weight='balanced'` in scikit-learn.
- `scale_pos_weight` in XGBoost: `scale_pos_weight = negative_count / positive_count`.
- **Focal loss** in PyTorch/TensorFlow for severe imbalance.

**At evaluation level:**
- Use **Precision-Recall AUC** instead of ROC-AUC.
- Focus on **F1-score, MCC** rather than accuracy.
- Threshold tuning based on business cost matrix.

**AWS-specific:**
- SageMaker Clarify reports class imbalance during preprocessing.
- SageMaker Autopilot handles imbalance automatically.

**Example XGBoost:**
```python
import xgboost as xgb

neg = (y_train == 0).sum()
pos = (y_train == 1).sum()
scale = neg / pos

model = xgb.XGBClassifier(
    scale_pos_weight=scale,
    eval_metric='aucpr',
    use_label_encoder=False
)
```

---

## 2. AWS AI/ML Ecosystem

---

### Q5. Describe the AWS AI/ML stack and how you have leveraged it in production.

**Answer:**

AWS AI/ML stack has three layers:

**Layer 1 – AI Services (Pre-built, No ML needed)**
| Service | Use Case |
|---------|----------|
| Amazon Rekognition | Image/video analysis |
| Amazon Comprehend | NLP, sentiment, entity extraction |
| Amazon Textract | Document OCR and extraction |
| Amazon Forecast | Time-series forecasting |
| Amazon Personalize | Recommendation systems |
| Amazon Kendra | Intelligent enterprise search |
| Amazon Bedrock | Foundation models (Anthropic, Titan, Llama) |

**Layer 2 – ML Platform (Amazon SageMaker)**
- SageMaker Studio: IDE for ML.
- SageMaker Pipelines: ML workflow orchestration (MLOps).
- SageMaker Training: Managed distributed training.
- SageMaker Experiments: Experiment tracking.
- SageMaker Model Monitor: Production monitoring.
- SageMaker Clarify: Bias detection and explainability.
- SageMaker Feature Store: Feature management.
- SageMaker Model Registry: Model versioning.
- SageMaker JumpStart: Pre-trained model hub.

**Layer 3 – ML Frameworks & Infrastructure**
- EC2 P3/P4d/P5 instances (V100/A100/H100 GPUs).
- Amazon EKS for Kubernetes-based ML workloads.
- AWS Batch for large-scale batch ML jobs.
- Amazon EMR for big data ML (Spark + MLlib).
- Amazon FSx for Lustre: High-throughput storage for training.

**Production Example:**
> Architected a fraud detection system: Data ingested via Kinesis → features computed by Glue → stored in SageMaker Feature Store → XGBoost model trained on SageMaker with HPO → deployed as SageMaker Real-Time Endpoint → monitored with Model Monitor → retraining triggered by EventBridge. Achieved <20ms p99 latency, 95% AUC.

---

### Q6. How does Amazon SageMaker Pipelines work and how does it enable MLOps?

**Answer:**

**SageMaker Pipelines** is a purpose-built CI/CD service for ML workflows, providing a directed acyclic graph (DAG) of pipeline steps.

**Key Pipeline Steps:**
```python
from sagemaker.workflow.steps import (
    ProcessingStep, TrainingStep,
    CreateModelStep, TransformStep
)
from sagemaker.workflow.pipeline import Pipeline
from sagemaker.workflow.conditions import ConditionGreaterThan
from sagemaker.workflow.condition_step import ConditionStep

# Define steps
step_process = ProcessingStep(name="PreProcessing", ...)
step_train = TrainingStep(name="ModelTraining", ...)
step_eval = ProcessingStep(name="ModelEvaluation", ...)

# Conditional registration
cond_register = ConditionStep(
    name="CheckAccuracy",
    conditions=[ConditionGreaterThan(left=accuracy, right=0.85)],
    if_steps=[step_register],
    else_steps=[step_fail]
)

pipeline = Pipeline(
    name="FraudDetectionPipeline",
    steps=[step_process, step_train, step_eval, cond_register]
)
pipeline.upsert(role_arn=role)
pipeline.start()
```

**MLOps enablement:**
- **Reproducibility**: Every run is tracked with parameters, artifacts, and metrics.
- **Automation**: Triggered by CodePipeline on new data arrival (S3 event → EventBridge → CodePipeline → SageMaker Pipeline).
- **Governance**: Approval gates in Model Registry before production promotion.
- **Lineage tracking**: SageMaker ML Lineage tracks dataset → training → model → endpoint.

---

### Q7. How would you architect a real-time ML inference solution on AWS for high-throughput, low-latency requirements?

**Answer:**

**Architecture for High-Throughput, Low-Latency Inference:**

```
Client → API Gateway → Lambda (Auth/Routing)
                    → SageMaker Real-Time Endpoint (primary)
                    → ElastiCache Redis (feature lookup)
                    → SageMaker Feature Store Online
```

**Key design decisions:**

1. **Model serving**: SageMaker Real-Time Endpoint with:
   - `ml.g4dn.xlarge` for GPU inference.
   - Multi-model endpoint to colocate related models.
   - Auto Scaling: Target tracking on `SageMakerVariantInvocationsPerInstance`.

2. **Model optimization**:
   - Convert to ONNX → TensorRT for GPU inference.
   - Use SageMaker Neo for hardware-specific compilation.
   - Quantization: INT8 for 4x speedup with minimal accuracy loss.

3. **Caching**:
   - Cache frequent predictions in ElastiCache Redis with TTL.
   - Cache feature lookups to avoid repeated feature store calls.

4. **Load balancing**:
   - SageMaker endpoint handles load balancing across multiple instances.
   - Shadow testing: Route 5% traffic to new model version.

5. **Latency targets**:
   - Feature retrieval: <5ms (Redis/SageMaker Online Store).
   - Model inference: <10ms (optimized model on GPU).
   - End-to-end p99: <50ms.

6. **Monitoring**:
   - CloudWatch: Latency, throughput, 4xx/5xx.
   - SageMaker Model Monitor: Data quality, model quality.

---

### Q8. How do you use Amazon Bedrock in enterprise AI architectures?

**Answer:**

**Amazon Bedrock** is a fully managed service providing access to Foundation Models (FMs) from Anthropic (Claude), Meta (Llama), Mistral, Cohere, and Amazon (Titan).

**Key capabilities:**

1. **Model Access**: API-based access to multiple FMs without managing infrastructure.
2. **Fine-tuning**: Fine-tune Titan and other models on proprietary data.
3. **Knowledge Bases**: RAG (Retrieval-Augmented Generation) with vector DB (OpenSearch Serverless).
4. **Agents**: Bedrock Agents for autonomous task execution with tool use.
5. **Guardrails**: Content filtering, PII redaction, topic blocking.

**RAG Architecture with Bedrock:**
```python
import boto3

bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')

response = bedrock_agent_runtime.retrieve_and_generate(
    input={'text': "What is CGI's AI policy?"},
    retrieveAndGenerateConfiguration={
        'type': 'KNOWLEDGE_BASE',
        'knowledgeBaseConfiguration': {
            'knowledgeBaseId': 'KB_ID',
            'modelArn': 'arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet'
        }
    }
)
print(response['output']['text'])
```

**Enterprise patterns:**
- Internal knowledge assistant using RAG + Bedrock Knowledge Bases.
- Code generation assistant integrated with developer IDEs.
- Document summarization pipeline: S3 → Lambda → Bedrock → DynamoDB.
- Guardrails for compliance: PII removal, hallucination mitigation.

---

### Q9. How do you handle data security and privacy in AWS ML workflows?

**Answer:**

**Data Security layers:**

1. **Encryption at rest**: S3 SSE-KMS, SageMaker notebooks encrypted with KMS keys.
2. **Encryption in transit**: TLS 1.2+ for all API calls.
3. **Network isolation**: VPC-only SageMaker training/endpoints with no internet access.
4. **IAM least privilege**: Role-based access; SageMaker execution roles with minimal permissions.
5. **Data governance**: AWS Lake Formation column-level and row-level security.
6. **PII handling**: Amazon Comprehend for PII detection; Macie for S3 PII scanning.
7. **Differential privacy**: Add noise during model training using TensorFlow Privacy.
8. **Model artifact security**: SageMaker Model Registry with private container images in ECR.

**Example IAM policy for SageMaker:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my-ml-bucket/training-data/*"
    },
    {
      "Effect": "Allow",
      "Action": ["sagemaker:CreateTrainingJob", "sagemaker:DescribeTrainingJob"],
      "Resource": "*"
    }
  ]
}
```

---

## 3. MLOps & CI/CD

---

### Q10. Design a complete MLOps pipeline on AWS from code commit to production deployment.

**Answer:**

**End-to-end MLOps pipeline on AWS:**

```
Developer pushes code
        ↓
    CodeCommit / GitHub
        ↓
    CodePipeline (trigger)
        ↓
    Stage 1: Build & Test
      CodeBuild → pytest, flake8 → Docker image → ECR
        ↓
    Stage 2: Data Validation
      SageMaker Processing Job → Great Expectations / Deequ
        ↓
    Stage 3: Model Training
      SageMaker Training Job → HPO → SageMaker Experiments
        ↓
    Stage 4: Model Evaluation
      SageMaker Processing Job → Metrics → Model Registry
      Conditional: Pass threshold?
        ↓ (if passed)
    Stage 5: Manual Approval
      SNS notification → Approver → Approve → Staging deploy
        ↓
    Stage 6: Staging Deploy
      SageMaker Endpoint (staging) → Integration tests / load tests
        ↓
    Stage 7: Production Deploy
      Blue/Green or Canary → SageMaker Traffic Splitting
      CloudWatch alarms → rollback
```

**Infrastructure as Code:** CDK/Terraform manages all SageMaker resources.
**Versioning:** DVC for data versioning, Git for code, SageMaker Model Registry for models.
**Observability:** CloudWatch dashboards + SageMaker Model Monitor.

---

### Q11. How do you manage model versioning and rollback in production?

**Answer:**

**Model Versioning Strategy:**

1. **SageMaker Model Registry:**
   - Every trained model is registered with metadata: training job ARN, dataset version, metrics.
   - Statuses: `PendingManualApproval` → `Approved` → `Rejected`.
   - Approved models trigger CodePipeline for deployment.

2. **DVC (Data Version Control):**
   - Track dataset and model artifacts alongside code.
   - `.dvc` files committed to Git, data stored in S3.
   ```bash
   dvc add data/train.csv
   dvc push  # pushes to s3://my-ml-bucket/dvc-store
   git add data/train.csv.dvc
   git commit -m "Add training data v2.3"
   ```

3. **Canary Deployment & Rollback:**
   ```python
   # Canary: route 10% traffic to new model
   sm.update_endpoint_weights_and_capacities(
       EndpointName='fraud-detection-endpoint',
       DesiredWeightsAndCapacities=[
           {'VariantName': 'ModelV1', 'DesiredWeight': 90},
           {'VariantName': 'ModelV2', 'DesiredWeight': 10}
       ]
   )

   # Rollback: shift 100% back to old model
   sm.update_endpoint_weights_and_capacities(
       EndpointName='fraud-detection-endpoint',
       DesiredWeightsAndCapacities=[
           {'VariantName': 'ModelV1', 'DesiredWeight': 100},
           {'VariantName': 'ModelV2', 'DesiredWeight': 0}
       ]
   )
   ```

4. **CloudWatch alarm-triggered rollback**: Lambda function triggered by alarm → update endpoint back to previous variant.

---

### Q12. Explain experiment tracking and why it matters in large-scale ML projects.

**Answer:**

**Experiment tracking** is the systematic logging of all parameters, metrics, artifacts, and metadata for every ML experiment run.

**Why it matters:**
- **Reproducibility**: Reproduce any past result exactly.
- **Comparison**: Compare 50 experiments in a single dashboard.
- **Debugging**: Trace why a model degraded.
- **Collaboration**: Multiple data scientists working on the same project.
- **Compliance**: Audit trail of model development.

**MLflow on AWS:**
```python
import mlflow
import mlflow.sklearn

mlflow.set_tracking_uri("http://mlflow-server:5000")
mlflow.set_experiment("fraud-detection-v3")

with mlflow.start_run(run_name="xgboost-hp-tuning-001"):
    mlflow.log_param("max_depth", 6)
    mlflow.log_param("learning_rate", 0.1)
    mlflow.log_param("n_estimators", 200)

    model.fit(X_train, y_train)

    mlflow.log_metric("val_auc", val_auc)
    mlflow.log_metric("val_f1", val_f1)
    mlflow.log_metric("training_time", elapsed)

    mlflow.sklearn.log_model(model, "model")
    mlflow.log_artifact("confusion_matrix.png")
```

**SageMaker Experiments** integrates natively with SageMaker Training and provides similar capabilities with AWS-native integration.

---

## 4. Kubernetes & GPU Workloads

---

### Q13. How do you deploy and manage ML workloads on Amazon EKS with GPU support?

**Answer:**

**EKS GPU Setup:**

1. **Node Groups with GPU instances:**
```yaml
nodeGroup:
  name: gpu-workers
  instanceType: p3.2xlarge
  desiredCapacity: 3
  minSize: 1
  maxSize: 10
  labels:
    hardware: nvidia-gpu
  taints:
    - key: nvidia.com/gpu
      value: "true"
      effect: NoSchedule
```

2. **NVIDIA Device Plugin:**
```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
```

3. **GPU Training Job manifest:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pytorch-training
spec:
  template:
    spec:
      nodeSelector:
        hardware: nvidia-gpu
      tolerations:
        - key: nvidia.com/gpu
          operator: Equal
          value: "true"
          effect: NoSchedule
      containers:
        - name: training
          image: 123456789.dkr.ecr.us-east-1.amazonaws.com/ml-training:latest
          resources:
            limits:
              nvidia.com/gpu: 4
          command: ["python", "train.py", "--epochs", "50"]
      restartPolicy: OnFailure
```

4. **Distributed training with Kubeflow MPI Operator:**
```yaml
apiVersion: kubeflow.org/v1
kind: MPIJob
metadata:
  name: distributed-training
spec:
  slotsPerWorker: 4
  mpiReplicaSpecs:
    Launcher:
      replicas: 1
      template:
        spec:
          containers:
            - name: launcher
              image: my-training-image
              command: ["mpirun", "python", "train_distributed.py"]
    Worker:
      replicas: 4
      template:
        spec:
          containers:
            - name: worker
              image: my-training-image
              resources:
                limits:
                  nvidia.com/gpu: 4
```

5. **GPU monitoring:** NVIDIA DCGM Exporter → Prometheus → Grafana. CloudWatch Container Insights for EKS.

---

### Q14. How do you optimize GPU utilization for ML training and inference?

**Answer:**

**Training Optimization:**

1. **Mixed Precision Training (AMP):**
```python
from torch.cuda.amp import autocast, GradScaler

scaler = GradScaler()
for batch in dataloader:
    with autocast():
        output = model(batch)
        loss = criterion(output, target)
    scaler.scale(loss).backward()
    scaler.step(optimizer)
    scaler.update()
```

2. **Data loading optimization:**
```python
DataLoader(
    dataset,
    num_workers=4,
    pin_memory=True,
    prefetch_factor=2,
    persistent_workers=True
)
```

3. **Gradient accumulation** for large effective batch sizes without OOM:
```python
ACCUMULATION_STEPS = 8
for i, batch in enumerate(dataloader):
    loss = model(batch) / ACCUMULATION_STEPS
    loss.backward()
    if (i + 1) % ACCUMULATION_STEPS == 0:
        optimizer.step()
        optimizer.zero_grad()
```

**Inference Optimization:**

1. **TensorRT conversion:**
```python
import torch_tensorrt

trt_model = torch_tensorrt.compile(
    model,
    inputs=[torch_tensorrt.Input((batch_size, 3, 224, 224))],
    enabled_precisions={torch.float16}
)
```

2. **ONNX export + TensorRT:**
```bash
trtexec --onnx=model.onnx --saveEngine=model.trt --fp16
```

3. **NVIDIA Triton Inference Server**: Batching, model ensembles, GPU/CPU routing.

4. **GPU metrics to track:** GPU utilization (target >80%), GPU memory utilization (target >70%), SM efficiency, DRAM bandwidth.

---

### Q15. Explain Kubeflow and how it fits into the ML platform on Kubernetes.

**Answer:**

**Kubeflow** is an open-source ML toolkit for Kubernetes providing:

| Component | Purpose |
|-----------|---------|
| Kubeflow Pipelines | DAG-based ML workflow orchestration |
| KFServing / KServe | Model serving on Kubernetes |
| Katib | Hyperparameter optimization |
| Training Operator | Distributed training (TFJob, PyTorchJob, MPIJob) |
| Jupyter Notebooks | Managed notebook servers |
| Model Registry | Model versioning |

**Kubeflow Pipeline example:**
```python
from kfp import dsl

@dsl.component(base_image="python:3.9")
def preprocess(input_path: str, output_path: str):
    pass

@dsl.component(base_image="pytorch/pytorch:latest")
def train(data_path: str, model_output: str, learning_rate: float):
    pass

@dsl.pipeline(name="ml-pipeline")
def ml_pipeline(input_path: str, lr: float = 0.001):
    preprocess_task = preprocess(input_path=input_path, output_path="/data/processed")
    train_task = train(
        data_path=preprocess_task.output,
        model_output="/models/v1",
        learning_rate=lr
    )

from kfp import compiler
compiler.Compiler().compile(ml_pipeline, 'pipeline.yaml')
```

**AWS integration:** Kubeflow on AWS integrates with S3, RDS, Cognito, ALB. Alternative: SageMaker Pipelines is often preferred for AWS-native MLOps.

---

## 5. Data Engineering & Pipelines

---

### Q16. How do you build scalable data pipelines for ML on AWS?

**Answer:**

**Data pipeline architecture on AWS:**

```
Data Sources (RDS, APIs, Streaming)
    ↓ Ingestion Layer
    Batch: AWS Glue, AWS DMS
    Streaming: Kinesis Data Streams / Firehose
    ↓
Raw Storage: S3 Data Lake (raw/)
    ↓ Processing Layer
    Batch: AWS Glue (Spark), EMR
    Streaming: Kinesis Analytics (Flink)
    ↓
Processed Storage: S3 (processed/), Redshift
    ↓
Feature Engineering: Glue / SageMaker Processing
    ↓
Feature Store: SageMaker Feature Store
    ↓
ML Training / Serving
```

**AWS Glue ETL example:**
```python
from awsglue.context import GlueContext
from pyspark.context import SparkContext
from pyspark.sql.functions import col, datediff, current_date

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

df = glueContext.create_dynamic_frame.from_catalog(
    database="ml_raw_db",
    table_name="transactions"
).toDF()

df_features = df.withColumn(
    "account_age_days",
    datediff(current_date(), col("account_open_date"))
)

df_features.write.parquet("s3://ml-bucket/processed/features/", mode="overwrite")
```

**Apache Airflow on MWAA:**
```python
from airflow import DAG
from airflow.providers.amazon.aws.operators.glue import GlueJobOperator
from airflow.providers.amazon.aws.operators.sagemaker import SageMakerTrainingOperator

with DAG("ml_pipeline", schedule_interval="@daily") as dag:
    etl = GlueJobOperator(job_name="feature-engineering", ...)
    train = SageMakerTrainingOperator(config=training_config, ...)
    etl >> train
```

---

### Q17. How do you ensure data quality in ML pipelines?

**Answer:**

**Data quality framework:**

1. **Schema validation**: Ensure expected columns, data types.
2. **Statistical validation**: Distribution checks, outlier detection.
3. **Completeness checks**: Null rates, row counts.
4. **Referential integrity**: Foreign key relationships.
5. **Temporal checks**: No future dates in historical data, sequence order.

**Great Expectations on AWS:**
```python
import great_expectations as ge

context = ge.get_context()
batch = context.get_batch({"path": "s3://bucket/train.csv"}, "my_suite")

batch.expect_column_to_exist("customer_id")
batch.expect_column_values_to_not_be_null("transaction_amount", mostly=0.99)
batch.expect_column_values_to_be_between("age", min_value=18, max_value=120)
batch.expect_column_mean_to_be_between("transaction_amount", min_value=10, max_value=1000)

results = context.run_validation_operator("action_list_operator", [batch])
```

**SageMaker Data Quality Monitor:**
- Creates a baseline on training data statistics.
- Compares inference input against baseline in production.
- Triggers alerts on schema changes or statistical drift.

---

## 6. LLMs & Generative AI

---

### Q18. Explain the RAG (Retrieval-Augmented Generation) pattern and how you would implement it on AWS.

**Answer:**

**RAG** combines information retrieval with generative models to answer questions grounded in your documents, reducing hallucinations.

**Components:**
1. **Document ingestion**: Chunk documents → embed → store in vector DB.
2. **Query processing**: Embed query → similarity search → retrieve top-K chunks.
3. **Generation**: Inject retrieved context into LLM prompt → generate grounded answer.

**AWS RAG Architecture:**
```
Documents (S3)
    ↓
Lambda (chunking + embedding via Bedrock Titan Embeddings)
    ↓
OpenSearch Serverless (vector store, k-NN index)
    ↓
Query Time: User query → Titan Embeddings → k-NN search → top-K docs
    ↓
Bedrock Claude: Prompt = system + context + query → answer
```

**Implementation:**
```python
import boto3, json

bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')

def get_embedding(text):
    response = bedrock.invoke_model(
        modelId='amazon.titan-embed-text-v1',
        body=json.dumps({"inputText": text})
    )
    return json.loads(response['body'].read())['embedding']

def generate_answer(query, context_docs):
    context = "\n\n".join([doc['content'] for doc in context_docs])
    prompt = f"""Based on the following context, answer the question.
Context: {context}
Question: {query}
Answer:"""

    response = bedrock.invoke_model(
        modelId='anthropic.claude-3-sonnet-20240229-v1:0',
        body=json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 1024,
            "messages": [{"role": "user", "content": prompt}]
        })
    )
    return json.loads(response['body'].read())['content'][0]['text']
```

**Enhancements:**
- **Hybrid search**: Combine BM25 (keyword) + vector (semantic) search.
- **Re-ranking**: Cross-encoder reranking of retrieved chunks.
- **Bedrock Knowledge Bases**: Fully managed RAG with minimal code.

---

### Q19. How do you fine-tune an open-source LLM for enterprise use cases?

**Answer:**

**Fine-tuning approaches by data size and budget:**

| Approach | When to Use | Data Required |
|----------|-------------|---------------|
| Prompt Engineering | Quick wins, no training | 0 examples |
| Few-shot Learning | Task-specific performance | 10–100 examples |
| LoRA / QLoRA | Efficient fine-tuning | 1K–100K examples |
| Full Fine-tuning | Maximum performance | 100K+ examples |

**QLoRA Fine-tuning on AWS SageMaker:**
```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model, TaskType
from trl import SFTTrainer
import torch

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.float16,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4"
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-7b-hf",
    quantization_config=bnb_config,
    device_map="auto"
)

lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=64,
    lora_alpha=16,
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.1,
    bias="none"
)

model = get_peft_model(model, lora_config)
# trainable params: ~0.5% of total

trainer = SFTTrainer(
    model=model,
    train_dataset=train_dataset,
    dataset_text_field="text",
    max_seq_length=2048,
    args=training_args
)
trainer.train()
```

**vLLM for efficient LLM serving:**
```python
from vllm import LLM, SamplingParams

llm = LLM(model="mistralai/Mistral-7B-v0.1", tensor_parallel_size=2)
outputs = llm.generate(["What is CGI's AI strategy?"],
                        SamplingParams(temperature=0.7, max_tokens=512))
```

---

### Q20. How do you evaluate and mitigate LLM hallucinations in production?

**Answer:**

**Hallucination types:**
- Factual: Claims false facts.
- Faithfulness: Not grounded in provided context.
- Consistency: Contradicts itself.

**Mitigation strategies:**

1. **RAG grounding**: Always retrieve relevant documents before generation.
2. **Fact-checking layer**: Secondary LLM call to verify claims against source.
3. **Confidence scoring**: Entropy of token probabilities as uncertainty signal.
4. **Prompt engineering**: "Answer ONLY based on the provided context. If unsure, say I don't know."
5. **Amazon Bedrock Guardrails**: Configure grounding check.

**Evaluation metrics:**
| Metric | Tool | Description |
|--------|------|-------------|
| RAGAS | ragas library | RAG-specific: faithfulness, relevancy |
| G-Eval | LLM-as-judge | GPT-4 scores coherence, correctness |
| BERTScore | bertscore | Semantic similarity with reference |
| FactScore | factscore | Fact-level precision against knowledge base |

```python
from ragas import evaluate
from ragas.metrics import faithfulness, answer_relevancy, context_precision

result = evaluate(
    dataset=eval_dataset,
    metrics=[faithfulness, answer_relevancy, context_precision]
)
print(result)
# {'faithfulness': 0.94, 'answer_relevancy': 0.87, 'context_precision': 0.91}
```

---

## 7. Responsible AI & Governance

---

### Q21. How do you implement model explainability and bias detection in enterprise ML?

**Answer:**

**Model Explainability Techniques:**

| Technique | Type | When to Use |
|-----------|------|-------------|
| SHAP | Global + Local | Tabular models |
| LIME | Local | Any model |
| Integrated Gradients | Local | Neural networks |
| Attention visualization | Local | Transformers |

**SHAP example:**
```python
import shap, xgboost as xgb

model = xgb.XGBClassifier()
model.fit(X_train, y_train)

explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(X_test)

shap.summary_plot(shap_values, X_test)
shap.force_plot(explainer.expected_value, shap_values[0], X_test.iloc[0])
```

**AWS SageMaker Clarify:**
```python
from sagemaker.clarify import (
    SageMakerClarifyProcessor, BiasConfig, DataConfig, ModelConfig, SHAPConfig
)

clarify_processor = SageMakerClarifyProcessor(role=role, ...)

bias_config = BiasConfig(
    label_values_or_threshold=[1],
    facet_name="gender",
    facet_values_or_threshold=["Female"]
)

shap_config = SHAPConfig(
    baseline=[X_train.mean().to_dict()],
    num_samples=500,
    agg_method="mean_abs"
)

clarify_processor.run_bias(
    data_config=data_config,
    bias_config=bias_config,
    model_config=model_config
)
```

**Bias metrics:**
- **DPL** (Difference in Positive Proportions): Measures representation bias.
- **DI** (Disparate Impact): Ratio of outcomes between groups.
- **CDDL** (Conditional Demographic Disparity): Conditional on label.

---

### Q22. Describe your approach to responsible AI and AI governance.

**Answer:**

**Responsible AI Framework:**

**1. Fairness**
- Define fairness criteria: individual vs. group fairness.
- Test model across demographic groups before production.
- Ongoing monitoring: SageMaker Clarify bias monitor.

**2. Transparency & Explainability**
- SHAP/LIME for model-level explanation.
- Data cards: document training data, collection method, known biases.
- Model cards: document intended use, performance, limitations.

**3. Privacy**
- PII detection and removal before training (Amazon Comprehend, Macie).
- Differential privacy for sensitive training data.
- Right to erasure: machine unlearning capabilities.

**4. Accountability**
- Full audit trail: ML Lineage Tracking in SageMaker.
- Human-in-the-loop for high-stakes decisions (credit, medical, hiring).
- Model approval gates: no model goes to production without review.

**5. Robustness**
- Adversarial testing against adversarial inputs.
- Edge case testing: performance on tail distributions.
- Stress testing under data drift scenarios.

**6. Environmental**
- Track carbon footprint of training jobs (CodeCarbon library).
- Prefer smaller, distilled models when accuracy requirements allow.
- Spot instances for training to reduce cost and energy.

**CGI-specific:** Align with CGI's IP protection policies. No proprietary client data used to train models externally. All models hosted on client-owned AWS accounts.

---

## 8. Leadership & Consulting

---

### Q23. How do you lead an AI/ML team delivering solutions for multiple client engagements?

**Answer:**

**Team structure for multi-client delivery:**

```
AI Lead
├── Data Engineers (2-3): Pipeline, feature engineering
├── ML Engineers (2-3): Model training, MLOps
├── Applied Scientists (1-2): Research, experimentation
└── Platform Engineer (1): Kubernetes, GPU infra
```

**Delivery practices:**

1. **Standardized project template**: Cookiecutter ML project with pre-configured MLOps tooling, reducing setup time by 80%.
2. **Reusable component library**: Feature transformers, model wrappers, deployment scripts shared across clients.
3. **Tech radar**: Quarterly evaluation of new tools (Adopt / Trial / Hold).
4. **Sprint rituals**: Weekly tech syncs, fortnightly model reviews, monthly retrospectives.
5. **Documentation standards**: Every model has a model card; every dataset has a data card.
6. **Code review**: ML-specific PR templates (data leakage check, reproducibility check).
7. **Knowledge sharing**: Internal wiki, lunch-and-learn sessions, post-project retrospectives.

**Mentoring approach:**
- Pair programming for junior team members.
- Assign stretch goals for mid-level engineers.
- 1:1 career conversations every 2 weeks.
- Encourage open-source contributions and conference presentations.

---

### Q24. How do you translate complex AI/ML concepts to business stakeholders?

**Answer:**

**Principles:**

1. **Lead with business impact**: "This model will reduce fraud losses by $2M/year" not "This model achieves 94% AUC."
2. **Use analogies**: "The model learns patterns from millions of past transactions, like an experienced fraud investigator."
3. **Avoid jargon**: Replace "gradient descent" with "iterative learning process."
4. **Visualize**: Confusion matrices → "Out of 1000 fraud cases, we catch 940."
5. **Risk framing**: Present both precision and recall as business trade-offs (false positives cost X, false negatives cost Y).

**Stakeholder communication matrix:**

| Stakeholder | Focus | Communication Style |
|-------------|-------|---------------------|
| C-Suite | Business ROI, risk | 1-slide exec summary |
| Product Manager | Features, timelines | User stories, demos |
| Engineering | Architecture, APIs | Technical docs, code |
| Compliance/Legal | Bias, explainability | Audit reports, model cards |
| End Users | How it affects their work | Training, demos |

---

### Q25. Describe how you handle technical debt in ML systems.

**Answer:**

**ML-specific technical debt types:**

1. **Glue code**: Notebooks promoted to production without refactoring.
   - Fix: Enforce `src/` package structure, CI runs pytest on all code.

2. **Pipeline jungles**: Multiple overlapping data pipelines.
   - Fix: Centralize in Apache Airflow/SageMaker Pipelines. Deprecate redundant pipelines.

3. **Undeclared consumers**: Models used by teams who never agreed to the interface.
   - Fix: API contracts, SLA definitions, versioned endpoints.

4. **Data dependency debt**: Silent data schema changes break models.
   - Fix: Great Expectations data quality gates in every pipeline step.

5. **Configuration debt**: Magic numbers in code.
   - Fix: Externalize all hyperparameters to config files (YAML/JSON), tracked in MLflow.

6. **Monitoring gaps**: Models running without performance dashboards.
   - Fix: Every production model must have a SageMaker Model Monitor schedule and CloudWatch dashboard.

**Debt remediation process:**
- Quarterly debt audit: score models on a technical debt rubric.
- Dedicate 20% of each sprint to debt reduction.
- Deprecation policy: models unused for 6 months are retired.

---

## 9. Scenario / Case Study Questions

---

### Q26. A model that was working well in production for 6 months suddenly shows a significant drop in accuracy. How do you diagnose and fix it?

**Answer:**

**Systematic debugging approach:**

**Step 1: Immediate triage (within 1 hour)**
- Check SageMaker Model Monitor reports: data drift, concept drift.
- Review CloudWatch metrics: prediction distribution, error rates.
- Check upstream data pipeline for failures: Glue job failures, schema changes.
- Review recent deployments: any code changes, dependency updates?

**Step 2: Data investigation**
```python
from scipy.stats import ks_2samp
import pandas as pd

baseline = pd.read_parquet("s3://bucket/baseline_stats.parquet")
current = pd.read_parquet("s3://bucket/current_stats.parquet")

for col in numerical_columns:
    stat, p_value = ks_2samp(baseline[col].dropna(), current[col].dropna())
    if p_value < 0.05:
        print(f"Drift detected in {col}: p-value={p_value:.4f}")
```

**Step 3: Root cause hypotheses**
- **Data drift**: Input features changed (seasonal, product changes).
- **Concept drift**: Relationship between features and labels changed (behavioral change).
- **Data quality issue**: Upstream bug introducing nulls, outliers.
- **Schema change**: New/missing column in inference data.
- **Infrastructure issue**: Wrong model version deployed.

**Step 4: Resolution**
- Short-term: If rollback improves performance → infrastructure issue, rollback immediately.
- Medium-term: Retrain on recent data including drifted distribution.
- Long-term: Implement automated retraining triggered by drift thresholds.

**Step 5: Communication**
- Immediate: Alert stakeholders within 30 min of detection.
- RCA report within 48 hours: what happened, why, how it was fixed, how it will be prevented.

---

### Q27. You are asked to architect an AI solution for a government client with strict data residency requirements. How do you approach this?

**Answer:**

**Constraints:**
- Data must stay in-country (e.g., Canada, UK, Australia).
- Strict compliance: GDPR, PIPEDA, etc.
- No data exfiltration to external services.
- Audit trail required.

**Architecture on AWS:**

1. **Region selection**: Deploy exclusively in `ca-central-1` (Canada), `eu-west-2` (UK), `ap-southeast-2` (Australia).
2. **AWS GovCloud**: For US federal clients, use `us-gov-west-1`.
3. **Data isolation**: Dedicated AWS account per client with SCP restricting data to specific regions.
4. **No external LLM calls**: Deploy open-source LLMs (Llama 3, Mistral) on private SageMaker endpoints.
5. **Network**: VPC with no internet gateways. All services accessed via VPC endpoints.
6. **Encryption**: Customer-managed KMS keys (CMK). Client owns and controls keys.
7. **Audit**: AWS CloudTrail for all API calls. CloudWatch Logs for model inference logs.
8. **Portability**: Use open standards (ONNX, MLflow) for model portability.

**Compliance documentation:**
- AWS Shared Responsibility Model explanation.
- SOC 2 Type II, ISO 27001 compliance reports from AWS.
- Data Processing Agreement (DPA) with client.

---

### Q28. How would you build an LLM-powered intelligent document processing solution for a financial services client on AWS?

**Answer:**

**Architecture:**

```
Documents (PDF/Images) → S3 (raw documents)
    ↓
Lambda trigger → Amazon Textract (OCR + structure extraction)
    ↓
S3 (extracted text) → Lambda → Amazon Bedrock Claude (entity extraction)
    ↓
DynamoDB (structured data) → API Gateway → Review UI
    ↓
Human-in-the-loop: A2I for low-confidence items (<85%)
    ↓
Redshift (analytics, reporting)
```

**Bedrock extraction prompt:**
```python
prompt = """Extract the following fields from this financial document:
- Invoice number
- Invoice date
- Vendor name
- Total amount
- Line items (description, quantity, unit price, total)

Document text: {document_text}

Return as valid JSON only."""
```

**Performance targets:**
- 95%+ extraction accuracy.
- <10 seconds per document (async for large documents).
- 70% reduction in manual processing time.

---

## 10. Behavioral / Situational Questions

---

### Q29. Tell me about a time you had to convince a client or stakeholder to adopt a different AI approach than what they originally requested.

**Answer (STAR format):**

**Situation**: A retail banking client requested a deep learning recommendation system for cross-sell after seeing impressive demos of neural collaborative filtering.

**Task**: Assess whether deep learning was truly the right approach given their constraints.

**Action**:
1. Conducted a thorough data audit: only 18 months of transaction history, ~50K customers — insufficient for robust deep learning.
2. Built a rapid PoC comparing: (a) neural collaborative filtering, (b) XGBoost + rule-based features, (c) Apriori association rules.
3. Presented results: Apriori achieved 78% precision, XGBoost achieved 82%, neural CF achieved 68% (overfit on small data).
4. Framed it as: "Your data is a strength — we can build a highly interpretable model that compliance can approve quickly and improve as data grows."
5. Proposed phased approach: deploy XGBoost now → accumulate data for 12 months → revisit deep learning.

**Result**: XGBoost solution went live in 8 weeks vs. 6+ months for deep learning. Generated $1.2M in cross-sell revenue in Q1. Compliance approved within 2 weeks due to SHAP explainability reports.

**Learning**: The best model is not always the most complex one. Data volume, latency, explainability, and time-to-market are equally important.

---

### Q30. How have you handled a situation where model performance was acceptable but the model was making biased predictions?

**Answer (STAR format):**

**Situation**: During pre-launch validation of a credit risk model, SageMaker Clarify revealed disparate impact — applicants from a specific demographic were rejected at 2.3x the rate of others at equivalent creditworthiness.

**Task**: Resolve bias without significantly degrading overall model performance, under a tight deadline.

**Action**:
1. **Root cause analysis**: Identified zip code (proxy for race) was a top SHAP feature.
2. **Feature removal**: Removed zip code and geo-proxies. DI dropped from 2.3x to 1.4x (still above threshold).
3. **Reweighting**: Applied in-processing bias mitigation — reweighted training samples to balance outcomes.
4. **Threshold adjustment**: Tuned decision threshold per group to equalize false positive rates.
5. **Trade-off analysis**: Final model: AUC dropped from 0.88 to 0.84 (acceptable). DI: 1.08 (compliant with CFPB 80% rule).
6. **Documentation**: Created a bias mitigation report for compliance and legal teams.
7. **Ongoing monitoring**: Configured SageMaker Clarify bias monitor to alert if DI exceeds 1.15 in production.

**Result**: Model launched on schedule with full regulatory compliance. No CFPB issues in 18 months of operation. Client expanded the engagement to two additional geographies.

**Learning**: Bias is not just an ethical issue — it's a legal and business risk. Proactive bias testing before launch is far cheaper than post-launch remediation.

---

## Bonus: Quick-Fire Technical Questions

| # | Question | Answer |
|---|----------|--------|
| B1 | Batch norm vs. layer norm? | BatchNorm normalizes across batch dimension (CNNs); LayerNorm normalizes across feature dimension (Transformers, RNNs). |
| B2 | What is the vanishing gradient problem? | Gradients become extremely small in early layers. Solved by ReLU activations, residual connections, LSTM gates. |
| B3 | When to use LSTM over Transformer? | LSTM for small datasets, low latency, memory constraints. Transformer for long sequences, parallel training, large data. |
| B4 | Online vs. Offline Feature Store? | Offline: historical features in S3 for training (high throughput). Online: real-time features in Redis/DynamoDB for serving (<10ms). |
| B5 | What is model quantization? | Reducing weight precision from FP32 to FP16 or INT8 to reduce model size and inference latency with minimal accuracy loss. |
| B6 | Explain LoRA in one sentence. | LoRA adds trainable low-rank matrices to frozen pre-trained model layers, enabling efficient fine-tuning with <1% of original parameters. |
| B7 | SageMaker Pipelines vs. Apache Airflow? | SageMaker Pipelines is ML-native (training, evaluation, deployment focused); Airflow is general-purpose workflow orchestration. Both can be used together. |
| B8 | What is data lineage? | Tracks origin, transformation, and consumption of data and models. Critical for debugging, compliance, and reproducibility. |
| B9 | What is shadow model deployment? | Running a new model in parallel with production, routing a copy of live traffic to validate performance before switchover. |
| B10 | p3.2xlarge vs. p4d.24xlarge? | p3.2xlarge: 1x V100 16GB GPU, entry-level. p4d.24xlarge: 8x A100 40GB GPUs + 400 Gbps NVLink, for large-scale distributed training. |

---

## Preparation Tips

> **For CGI interviews, emphasize:**
> - Client delivery experience and business outcomes, not just technical depth.
> - Open-source tools (not just AWS managed services) — CGI values tool-agnostic expertise.
> - Responsible AI and governance — CGI has a public AI ethics framework.
> - MLOps maturity — production deployment and monitoring, not just model accuracy.
> - Consulting mindset: adaptability, stakeholder management, solution trade-offs.

> **Must-prepare AWS services:**
> Amazon SageMaker (all sub-services), Amazon Bedrock, AWS Glue, Amazon EMR, Amazon EKS, AWS Step Functions, Amazon Kinesis, Amazon MWAA (Airflow), AWS Lambda, Amazon S3, Amazon CloudWatch, AWS KMS, Amazon VPC, AWS IAM, Amazon ECR.

> **Certifications that strengthen your profile:**
> - AWS Certified Machine Learning – Specialty
> - AWS Certified Solutions Architect – Professional
> - Kubeflow / MLflow community certifications
> - NVIDIA Deep Learning Institute certificates (GPU optimization)

---

*Document prepared for: CGI Senior AI/ML Lead / Architect Interview Preparation*
*Focus: AWS AI/ML Ecosystem | MLOps | Kubernetes/GPU | LLMs | Responsible AI | Leadership*
*Experience Band: 8–12 Years*
