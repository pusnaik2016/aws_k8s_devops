# ADR-001: pgvector over OpenSearch for Vector Search

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2024-01-15 |
| **Decision Makers** | Pushparaj Naik |

---

## Context

OmniPresenseAI requires vector similarity search for the RAG (Retrieval-Augmented Generation) pipeline. When a user sends a chat message, we generate an embedding and retrieve the top-5 most relevant knowledge base documents to provide context to Claude 3.5 Sonnet.

Two primary options were evaluated:
1. **Amazon OpenSearch Service** with k-NN plugin
2. **Aurora PostgreSQL** with the `pgvector` extension

---

## Decision

We chose **Aurora PostgreSQL + pgvector** as our vector database.

---

## Rationale

### 1. Operational Simplicity — Single Database

| Aspect | pgvector (Aurora) | OpenSearch |
|--------|-------------------|-----------|
| Additional service to manage | ❌ No (reuse Aurora) | ✅ Yes (new cluster) |
| Transactional + vector in one DB | ✅ Yes | ❌ Separate systems |
| Backup strategy | Single RDS backup | Two backup strategies |
| Monitoring | Single set of metrics | Two sets of metrics |

By using pgvector, we avoid introducing an entirely new service. Aurora PostgreSQL already stores chat sessions, messages, and user data — adding vector search to the same database eliminates data synchronization complexity.

### 2. Cost

| Component | pgvector (Aurora) | OpenSearch |
|-----------|-------------------|-----------|
| Compute | $0 incremental (shared Aurora) | ~$150/mo (2× m6g.large.search) |
| Storage | ~$1/mo (10 GiB vectors) | ~$15/mo (gp3 storage) |
| Data transfer | Internal | Cross-service |
| **Total incremental** | **~$1/mo** | **~$165/mo** |

pgvector adds negligible cost since it runs on the existing Aurora cluster.

### 3. Performance — Sufficient for Our Scale

| Metric | pgvector (HNSW) | OpenSearch (k-NN) |
|--------|-----------------|-------------------|
| Query latency (10K docs) | ~5–10ms | ~2–5ms |
| Query latency (100K docs) | ~15–30ms | ~5–10ms |
| Index build time | Moderate | Fast |
| Memory usage | Moderate | High |

At our expected scale (< 50K knowledge documents), pgvector with HNSW indexing provides sub-30ms query latency — well within our 2-second response budget for the full RAG pipeline.

### 4. Consistency

With pgvector, knowledge base updates are immediately consistent (ACID transactions). OpenSearch uses eventual consistency, which could cause RAG to miss recently added documents.

---

## Trade-offs Accepted

- **Scale ceiling:** pgvector performance degrades beyond ~1M vectors. If we exceed this, we'll re-evaluate.
- **Advanced search features:** OpenSearch provides better full-text search, faceting, and aggregation. We don't need these for RAG retrieval.
- **Dedicated vector resources:** pgvector shares Aurora compute. Under extreme vector query load, it could impact transactional queries.

---

## Consequences

- Knowledge base documents and embeddings stored in Aurora PostgreSQL
- HNSW index created with `vector_cosine_ops` for cosine similarity
- No additional infrastructure to provision or maintain
- Single backup and recovery strategy
- If scale exceeds 1M documents, revisit with OpenSearch or Pinecone
