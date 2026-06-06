##############################################################################
# GitHub Secrets Setup Guide
# This file documents every secret required to run the GitHub Actions CI/CD.
# Store this in your repo — it contains NO secret values, only names & docs.
##############################################################################

# ┌────────────────────────────────────────────────────────────────────────────┐
# │                    REQUIRED GITHUB SECRETS                                 │
# │  Settings → Secrets and variables → Actions → New repository secret       │
# └────────────────────────────────────────────────────────────────────────────┘

# ─────────────────────────────────────────────────────
# AWS_ACCESS_KEY_ID
#   IAM access key with the following permissions:
#     - ce:GetCostAndUsage                   (Cost Explorer — must be Resource: *)
#     - dynamodb:* on your cost-history table
#     - lambda:*  on your Lambda functions
#     - sns:*     on your alert topic
#     - iam:*     for role/policy management
#     - scheduler:* for EventBridge schedulers
#     - logs:*    for CloudWatch log groups
#     - bedrock:InvokeModel
#
#   Recommended: use a dedicated CI IAM user with the minimum policy below.
#   Better: switch to OIDC (no long-lived keys) — see OIDC section.
#
# ─────────────────────────────────────────────────────
# AWS_SECRET_ACCESS_KEY
#   Companion secret for AWS_ACCESS_KEY_ID.
#
# ─────────────────────────────────────────────────────
# AWS_REGION
#   AWS region to deploy into.
#   Example: us-east-1
#
# ─────────────────────────────────────────────────────
# TF_VAR_ALERT_EMAIL
#   Email address to receive cost anomaly alerts.
#   Example: ops@yourcompany.com
#   Note: After first deploy, confirm the SNS subscription link in your inbox.
#
# ─────────────────────────────────────────────────────
# BEDROCK_MODEL_ID          (optional, has default)
#   Bedrock model ID if you want to override the default.
#   Default: anthropic.claude-3-5-sonnet-20241022-v2:0
#   Must be enabled in your AWS Account → Bedrock Console → Model access.
#
# ─────────────────────────────────────────────────────
# AWS_ROLE_ARN              (optional — for OIDC only)
#   IAM Role ARN for OIDC authentication.
#   Example: arn:aws:iam::123456789012:role/github-actions-cost-anomaly
#   Use this instead of AWS_ACCESS_KEY_ID/SECRET to avoid long-lived credentials.
# ─────────────────────────────────────────────────────

###############################################################################
# Minimum IAM Policy for CI User
###############################################################################
#
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "CostExplorer",
#       "Effect": "Allow",
#       "Action": ["ce:GetCostAndUsage"],
#       "Resource": ["*"]
#     },
#     {
#       "Sid": "DynamoDB",
#       "Effect": "Allow",
#       "Action": ["dynamodb:*"],
#       "Resource": ["arn:aws:dynamodb:<REGION>:<ACCOUNT_ID>:table/cost-history-*"]
#     },
#     {
#       "Sid": "Lambda",
#       "Effect": "Allow",
#       "Action": ["lambda:*"],
#       "Resource": ["arn:aws:lambda:<REGION>:<ACCOUNT_ID>:function:cost-anomaly-*"]
#     },
#     {
#       "Sid": "SNS",
#       "Effect": "Allow",
#       "Action": ["sns:*"],
#       "Resource": ["arn:aws:sns:<REGION>:<ACCOUNT_ID>:cost-anomaly-*"]
#     },
#     {
#       "Sid": "IAM",
#       "Effect": "Allow",
#       "Action": [
#         "iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy",
#         "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
#         "iam:GetRole", "iam:GetRolePolicy", "iam:ListAttachedRolePolicies",
#         "iam:ListRolePolicies", "iam:PassRole", "iam:TagRole"
#       ],
#       "Resource": ["arn:aws:iam::<ACCOUNT_ID>:role/cost-anomaly-*"]
#     },
#     {
#       "Sid": "Scheduler",
#       "Effect": "Allow",
#       "Action": ["scheduler:*"],
#       "Resource": ["arn:aws:scheduler:<REGION>:<ACCOUNT_ID>:schedule/default/cost-anomaly-*"]
#     },
#     {
#       "Sid": "CloudWatchLogs",
#       "Effect": "Allow",
#       "Action": ["logs:*"],
#       "Resource": ["arn:aws:logs:<REGION>:<ACCOUNT_ID>:log-group:/aws/lambda/cost-anomaly-*"]
#     },
#     {
#       "Sid": "Bedrock",
#       "Effect": "Allow",
#       "Action": ["bedrock:InvokeModel"],
#       "Resource": ["arn:aws:bedrock:<REGION>::foundation-model/anthropic.claude-*"]
#     }
#   ]
# }

###############################################################################
# OIDC Setup (Recommended — No Long-Lived Keys)
###############################################################################
#
# 1. Create an OIDC identity provider in IAM:
#    Provider URL : https://token.actions.githubusercontent.com
#    Audience     : sts.amazonaws.com
#
# 2. Create an IAM role with the trust policy:
# {
#   "Version": "2012-10-17",
#   "Statement": [{
#     "Effect": "Allow",
#     "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
#     "Action": "sts:AssumeRoleWithWebIdentity",
#     "Condition": {
#       "StringEquals": {
#         "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
#       },
#       "StringLike": {
#         "token.actions.githubusercontent.com:sub": "repo:<YOUR_GITHUB_ORG>/<YOUR_REPO>:*"
#       }
#     }
#   }]
# }
#
# 3. Attach the minimum IAM policy above to this role.
# 4. Set AWS_ROLE_ARN secret in GitHub to this role's ARN.
# 5. Uncomment the OIDC step in each workflow and remove the Access Keys step.

###############################################################################
# GitHub Environment Setup
###############################################################################
#
# For the `terraform-apply.yml` workflow to require human approval before
# deploying to production, configure a "production" GitHub Environment:
#
#   Settings → Environments → New environment → "production"
#   → Add required reviewers (e.g. @pushparajnaik)
#   → Set deployment branch: main
#
# This adds a manual approval gate before every `terraform apply`.
