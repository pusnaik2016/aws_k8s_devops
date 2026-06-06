#!/bin/bash
# Monitoring Setup Script - Prometheus & Grafana via Helm
# Author: Pushparaj Naik

set -e

echo "=== Setting up Monitoring Stack ==="

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus + Grafana stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi \
  --wait

echo "=== Monitoring Stack Deployed ==="
echo "Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "Prometheus: kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090"
