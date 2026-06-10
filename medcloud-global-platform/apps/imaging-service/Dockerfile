# Imaging Service — Dockerfile (Python 3.12 / FastAPI on Azure AKS)
FROM python:3.12-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim AS runtime
RUN groupadd -r medcloud && useradd -r -g medcloud medcloud
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /root/.local /home/medcloud/.local
ENV PATH=/home/medcloud/.local/bin:$PATH
COPY src/ ./src/
COPY config/ ./config/
USER medcloud:medcloud
LABEL org.opencontainers.image.title="MedCloud Imaging Service" \
      org.opencontainers.image.description="DICOM Processing — Azure AI Vision + Blob Storage" \
      compliance.hipaa="true"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=25s --retries=3 \
  CMD curl -f http://localhost:8080/health/live || exit 1
ENTRYPOINT ["python", "-m", "uvicorn", "src.main:app", \
  "--host", "0.0.0.0", "--port", "8080", "--workers", "2", "--log-level", "info"]
