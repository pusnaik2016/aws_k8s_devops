# Multi-stage, distroless, non-root Dockerfile
# PCI-DSS 6.3: Secure development practices
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

FROM gcr.io/distroless/python3-debian12:nonroot
WORKDIR /app
COPY --from=builder /deps /deps
COPY src/ /app/
ENV PYTHONPATH=/deps
ENV PYTHONUNBUFFERED=1
EXPOSE 8000
USER nonroot:nonroot
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/live')" || exit 1
ENTRYPOINT ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
