# =============================================================================
# Multi-stage Dockerfile — Transaction Ingestion Service
# =============================================================================
# Stage 1: Build dependencies
# Stage 2: Production-slim runtime (non-root, read-only compatible)
# =============================================================================

# ── Stage 1: Builder ──
FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: Production ──
FROM python:3.12-slim AS production

# Security: Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

# Install dependencies from builder
COPY --from=builder /install /usr/local

# Application code
WORKDIR /app
COPY app/ ./app/

# Security hardening
RUN chown -R appuser:appuser /app && \
    chmod -R 555 /app

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import httpx; httpx.get('http://localhost:8000/health').raise_for_status()"

EXPOSE 8000

# Run with uvicorn — production settings
CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "4", \
     "--access-log", \
     "--proxy-headers", \
     "--forwarded-allow-ips", "*"]
