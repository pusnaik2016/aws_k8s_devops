# Sample Dockerfile — Backend Application
# Purpose: Example with INTENTIONAL issues for scanner demo
# =============================================================================

FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# ⚠️ Scanner will flag: No USER directive (runs as root)
# ⚠️ Scanner will flag: No HEALTHCHECK instruction

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
