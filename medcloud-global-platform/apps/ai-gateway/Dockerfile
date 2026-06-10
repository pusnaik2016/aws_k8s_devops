# ─────────────────────────────────────────────────────────────────────────────
# AI Gateway — Multi-stage Dockerfile (Python 3.12 / FastAPI)
# ─────────────────────────────────────────────────────────────────────────────

# Stage 1: Builder
FROM python:3.12-slim AS builder
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim AS runtime

# Security: Create non-root user
RUN groupadd -r medcloud && useradd -r -g medcloud medcloud

# Install curl for health checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /root/.local /home/medcloud/.local
ENV PATH=/home/medcloud/.local/bin:$PATH

# Copy application code
COPY src/ ./src/
COPY config/ ./config/

# Security: Non-root user
USER medcloud:medcloud

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.opencontainers.image.title="MedCloud AI Gateway" \
      org.opencontainers.image.description="ML Inference Gateway — Fraud Detection & Recommendations" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      compliance.hipaa="true"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:8080/health/live || exit 1

ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", \
  "--host", "0.0.0.0", "--port", "8080", \
  "--workers", "4", "--log-level", "info"]
