#!/bin/bash
# GitHub OIDC Setup Script for AWS
# Author: Pushparaj Naik

set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
GITHUB_ORG="pushparajnaik"
GITHUB_REPO="3Tier_EKS_React"
ROLE_NAME="pushparaj-github-actions-role"

echo "=== Setting up GitHub OIDC for AWS ==="
echo "Account ID: $ACCOUNT_ID"

# Create OIDC Provider
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
  2>/dev/null || echo "OIDC Provider already exists"

# Create trust policy
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create IAM Role
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  2>/dev/null || echo "Role already exists"

# Attach EKS policy
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "eks-access" \
  --policy-document file://eks-policy.json

echo "=== OIDC Setup Complete ==="
echo "Role ARN: arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
