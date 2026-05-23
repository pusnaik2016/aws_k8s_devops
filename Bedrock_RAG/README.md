# 🤖 Enterprise RAG Chatbot on Amazon Bedrock

> **Author:** Pushparaj Naik  
> **Stack:** Terraform + Python + Amazon Bedrock + OpenSearch Serverless  
> **Status:** Production-Ready Architecture

An enterprise-grade Retrieval-Augmented Generation (RAG) chatbot built on AWS serverless services. Features three generation strategies (RAG, CAG), comprehensive security with Bedrock Guardrails, and zero NAT Gateway costs via VPC Endpoints.

---

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌───────────────────┐
│   Client /   │────▶│ API Gateway  │────▶│  Lambda (Router)  │
│   Web UI     │     │  (REST API)  │     │  Python 3.12      │
└──────────────┘     │  + CORS      │     └────┬─────────┬────┘
                     └──────────────┘          │         │
                                               │         │
                                    ┌──────────▼──┐  ┌───▼──────────┐
                                    │  RAG Path   │  │  CAG Path    │
                                    │  OpenSearch  │  │  Prompt      │
                                    │  kNN Search  │  │  Caching     │
                                    └──────┬──────┘  └──────┬───────┘
                                           │                │
                                    ┌──────▼────────────────▼───────┐
                                    │      Amazon Bedrock            │
                                    │  Claude 3.5 Sonnet v2         │
                                    │  + Titan Embed v2             │
                                    │  + Guardrails (PII, Content)  │
                                    └───────────────────────────────┘

Data Ingestion:
  S3 (documents/) ──trigger──▶ Lambda (Ingest)
    → Parse → Semantic Chunk → Titan Embed → OpenSearch Index
    → Save processed text to S3 (processed/) for CAG
```

## Generation Strategies

| Strategy | How It Works | Best For | Cost |
|----------|-------------|----------|------|
| **RAG** | Embed query → kNN search → top-K chunks → LLM | Large document sets (1000+ pages) | Standard |
| **CAG** | Full KB in prompt + prompt caching | Small KB (<100 pages), repeated queries | **90% cheaper** on cache hits |

## Project Structure

```
Bedrock_RAG/
├── terraform/                          # Infrastructure as Code
│   ├── main.tf                         # Root module — orchestrates all modules
│   ├── variables.tf                    # Environment configuration
│   ├── outputs.tf                      # API URL, bucket name, endpoints
│   └── modules/
│       ├── networking/                 # VPC, subnets, SGs, VPC Endpoints
│       ├── s3/                         # Document bucket (KMS encrypted)
│       ├── opensearch/                 # OpenSearch Serverless (vector search)
│       ├── iam/                        # Least-privilege Lambda roles
│       ├── lambda/                     # Chat + Ingest functions
│       ├── api_gateway/                # REST API with CORS
│       └── bedrock/                    # Guardrails (PII, content filter)
│
├── app/                                # Python application code
│   ├── lambda_handler.py               # Main entry — query router
│   ├── rag_engine.py                   # RAG pipeline (embed → search → generate)
│   ├── cag_engine.py                   # CAG pipeline (cached prompt generation)
│   ├── embeddings.py                   # Titan Embed v2 wrapper
│   ├── requirements.txt                # Python dependencies
│   └── ingest/
│       └── handler.py                  # S3-triggered document ingestion
│
├── .github/workflows/deploy.yml        # CI/CD pipeline
├── .gitignore
└── README.md
```

## Quick Start

### Prerequisites
- AWS account with Bedrock access (Claude + Titan Embed models enabled)
- Terraform >= 1.5
- Python >= 3.12
- AWS CLI configured

### Deploy

```bash
# 1. Clone and navigate
cd Bedrock_RAG

# 2. Initialize Terraform
cd terraform
terraform init

# 3. Plan
terraform plan

# 4. Apply
terraform apply

# 5. Note the outputs
terraform output
# api_gateway_url = "https://xxx.execute-api.us-east-1.amazonaws.com/dev"
# s3_bucket_name  = "bedrock-rag-documents-dev"
```

### Upload Documents

```bash
# Upload documents to trigger automatic ingestion
aws s3 cp my-knowledge-base.txt s3://bedrock-rag-documents-dev/documents/
aws s3 cp company-policies.md s3://bedrock-rag-documents-dev/documents/

# The ingest Lambda automatically:
# 1. Reads the document
# 2. Chunks it semantically
# 3. Generates embeddings (Titan Embed v2)
# 4. Indexes into OpenSearch Serverless
```

### Query the Chatbot

```bash
# RAG query (default)
curl -X POST https://xxx.execute-api.us-east-1.amazonaws.com/dev/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "What is our return policy?", "strategy": "rag", "top_k": 5}'

# CAG query (uses prompt caching — cheaper for repeated queries)
curl -X POST https://xxx.execute-api.us-east-1.amazonaws.com/dev/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "What is our return policy?", "strategy": "cag"}'

# Health check
curl https://xxx.execute-api.us-east-1.amazonaws.com/dev/health
```

### Response Format

```json
{
  "answer": "Based on the company policies document, the return policy allows...",
  "sources": ["company-policies.md"],
  "strategy": "rag",
  "model": "anthropic.claude-3-5-sonnet-20241022-v2:0",
  "latency_ms": 1842,
  "token_usage": {
    "input_tokens": 1523,
    "output_tokens": 312,
    "estimated_cost_usd": 0.009249
  }
}
```

## Security Architecture

| Layer | Implementation |
|-------|---------------|
| **Network** | Private subnets only, no NAT Gateway, VPC Endpoints for all AWS services |
| **Encryption (rest)** | KMS CMK for S3, Lambda env vars, CloudWatch Logs |
| **Encryption (transit)** | TLS 1.3 via VPC Endpoints and API Gateway |
| **IAM** | Least-privilege per function — scoped to specific models, buckets, indices |
| **Content Safety** | Bedrock Guardrails — PII anonymization, prompt attack detection, topic denial |
| **API Security** | API Gateway with optional Cognito auth, request validation, CORS |
| **Audit** | CloudWatch Logs, X-Ray tracing, API Gateway access logs |

## Cost Optimization

| Component | Monthly Cost (dev) | Optimization |
|-----------|-------------------|--------------|
| OpenSearch Serverless | ~$30 (2 OCU min) | Scales to zero when idle |
| Lambda | ~$5 | Pay per invocation only |
| API Gateway | ~$3 | Pay per request |
| VPC Endpoints | ~$21 (3 interface endpoints) | Cheaper than NAT Gateway ($32+) |
| Bedrock (Claude) | Pay per token | CAG prompt caching = 90% savings |
| S3 | < $1 | Lifecycle policies to IA/Glacier |
| **Total** | **~$60/month** | |

## CI/CD Pipeline

```
PR Created → Python Lint → Terraform Validate → Checkov Scan → Terraform Plan (PR comment)
PR Merged  → Python Lint → Terraform Validate → Terraform Apply → Smoke Test
```

---

**Built with ❤️ by Pushparaj Naik**
