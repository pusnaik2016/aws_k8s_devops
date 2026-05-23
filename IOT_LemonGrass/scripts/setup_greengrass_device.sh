#!/bin/bash
# =============================================================================
# AWS IoT Greengrass v2 — Edge Device Setup Script
# =============================================================================
# This script provisions a Greengrass v2 Core device by:
# 1. Installing Java (Greengrass Nucleus dependency)
# 2. Downloading the Greengrass Nucleus
# 3. Installing with the device certificate and config
# 4. Starting the Greengrass systemd service
#
# Usage:
#   ./setup_greengrass_device.sh \
#     --thing-name iot-greengrass-site-mumbai \
#     --thing-group iot-greengrass-fleet \
#     --tes-role-alias iot-greengrass-GreengrassTESAlias \
#     --region us-east-1 \
#     --cert-dir /path/to/certs
#
# Author: Pushparaj Naik
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
THING_NAME=""
THING_GROUP=""
TES_ROLE_ALIAS=""
AWS_REGION="us-east-1"
CERT_DIR=""
GG_ROOT="/greengrass/v2"

while [[ $# -gt 0 ]]; do
  case $1 in
    --thing-name) THING_NAME="$2"; shift 2;;
    --thing-group) THING_GROUP="$2"; shift 2;;
    --tes-role-alias) TES_ROLE_ALIAS="$2"; shift 2;;
    --region) AWS_REGION="$2"; shift 2;;
    --cert-dir) CERT_DIR="$2"; shift 2;;
    --gg-root) GG_ROOT="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

# Validate required args
for var in THING_NAME THING_GROUP TES_ROLE_ALIAS CERT_DIR; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: --$(echo $var | tr '_' '-' | tr '[:upper:]' '[:lower:]') is required"
    exit 1
  fi
done

echo "=============================================="
echo "  Greengrass v2 Device Setup"
echo "=============================================="
echo "  Thing Name:     $THING_NAME"
echo "  Thing Group:    $THING_GROUP"
echo "  TES Role Alias: $TES_ROLE_ALIAS"
echo "  Region:         $AWS_REGION"
echo "  Cert Dir:       $CERT_DIR"
echo "  GG Root:        $GG_ROOT"
echo "=============================================="

# ---------------------------------------------------------------------------
# Step 1: Install prerequisites
# ---------------------------------------------------------------------------
echo "[1/5] Installing prerequisites..."
if command -v apt-get &>/dev/null; then
  sudo apt-get update -y
  sudo apt-get install -y default-jdk curl unzip
elif command -v yum &>/dev/null; then
  sudo yum install -y java-11-amazon-corretto curl unzip
fi

java -version 2>&1 | head -1
echo "[OK] Java installed"

# ---------------------------------------------------------------------------
# Step 2: Create Greengrass user and group
# ---------------------------------------------------------------------------
echo "[2/5] Creating ggc_user and ggc_group..."
sudo useradd --system ggc_user 2>/dev/null || true
sudo groupadd --system ggc_group 2>/dev/null || true
sudo usermod -aG ggc_group ggc_user 2>/dev/null || true
echo "[OK] User and group created"

# ---------------------------------------------------------------------------
# Step 3: Download Greengrass Nucleus
# ---------------------------------------------------------------------------
echo "[3/5] Downloading Greengrass Nucleus..."
GG_INSTALLER_DIR="/tmp/gg-installer"
mkdir -p "$GG_INSTALLER_DIR"
curl -s https://d2s8p88vqu9w66.cloudfront.net/releases/greengrass-nucleus-latest.zip \
  -o "$GG_INSTALLER_DIR/greengrass-nucleus.zip"
unzip -qo "$GG_INSTALLER_DIR/greengrass-nucleus.zip" -d "$GG_INSTALLER_DIR/GreengrassInstaller"
echo "[OK] Greengrass Nucleus downloaded"

# ---------------------------------------------------------------------------
# Step 4: Install Greengrass Nucleus
# ---------------------------------------------------------------------------
echo "[4/5] Installing Greengrass Nucleus..."

# Extract site name from thing name for certificate lookup
SITE_NAME="${THING_NAME#iot-greengrass-}"

sudo -E java -Droot="$GG_ROOT" -Dlog.store=FILE \
  -jar "$GG_INSTALLER_DIR/GreengrassInstaller/lib/Greengrass.jar" \
  --aws-region "$AWS_REGION" \
  --thing-name "$THING_NAME" \
  --thing-group-name "$THING_GROUP" \
  --tes-role-name "iot-greengrass-greengrass-tes-role" \
  --tes-role-alias-name "$TES_ROLE_ALIAS" \
  --component-default-user ggc_user:ggc_group \
  --provision false \
  --setup-system-service true \
  --certificate-file-path "$CERT_DIR/${SITE_NAME}-certificate.pem" \
  --private-key-path "$CERT_DIR/${SITE_NAME}-private.key" \
  --root-ca-path "$CERT_DIR/AmazonRootCA1.pem"

echo "[OK] Greengrass Nucleus installed"

# ---------------------------------------------------------------------------
# Step 5: Start and verify
# ---------------------------------------------------------------------------
echo "[5/5] Starting Greengrass service..."
sudo systemctl enable greengrass.service
sudo systemctl start greengrass.service
sleep 5

if sudo systemctl is-active --quiet greengrass.service; then
  echo "=============================================="
  echo "  ✅ Greengrass v2 is RUNNING"
  echo "=============================================="
  echo "  Logs:   sudo tail -f $GG_ROOT/logs/greengrass.log"
  echo "  Status: sudo systemctl status greengrass.service"
  echo "  CLI:    sudo $GG_ROOT/bin/greengrass-cli component list"
  echo "=============================================="
else
  echo "❌ ERROR: Greengrass failed to start"
  sudo journalctl -u greengrass.service -n 20
  exit 1
fi
