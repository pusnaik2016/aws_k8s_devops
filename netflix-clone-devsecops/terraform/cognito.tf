# ==============================================================================
# Amazon Cognito — User Authentication and Identity Management
# ==============================================================================
# Provisions a Cognito User Pool for managing user authentication:
#
#   User Pool:
#     - Email-based sign-up and sign-in
#     - Password policy (min 8 chars, mixed case, numbers, symbols)
#     - Auto-verification via email
#     - Optional MFA (TOTP — Time-based One-Time Password)
#
#   User Pool Client:
#     - OAuth2 authorization code + implicit grant flows
#     - JWT tokens (access, ID, refresh) for API Gateway authorization
#     - Scopes: openid, email, profile
#
#   User Pool Domain:
#     - Cognito-hosted login UI (no custom domain needed)
#     - Provides sign-up, sign-in, and password reset flows
#
# Integration:
#   API Gateway uses the Cognito User Pool as a JWT authorizer.
#   Clients authenticate with Cognito → receive JWT → call API Gateway.
# ==============================================================================

# =============================================================================
# Cognito User Pool — User identity store and authentication engine
# =============================================================================
resource "aws_cognito_user_pool" "app" {
  name = "${var.project_name}-user-pool"

  # ---------------------------------------------------------------------------
  # Sign-in Configuration — Use email as the primary identifier
  # Users sign in with their email address instead of a separate username
  # ---------------------------------------------------------------------------
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"] # Auto-verify email on sign-up

  # ---------------------------------------------------------------------------
  # Password Policy — Enforce strong passwords
  # Minimum 8 characters with mixed case, numbers, and symbols
  # ---------------------------------------------------------------------------
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # ---------------------------------------------------------------------------
  # MFA Configuration — Optional TOTP (Google Authenticator, Authy, etc.)
  # Set to OPTIONAL so users can enable MFA from their account settings
  # Change to "ON" to require MFA for all users in production
  # ---------------------------------------------------------------------------
  # PCI DSS Req 8.4 + HIPAA: MFA required for all users
  mfa_configuration = "ON"

  software_token_mfa_configuration {
    enabled = true
  }

  # ---------------------------------------------------------------------------
  # User Attribute Schema — Define user profile fields
  # ---------------------------------------------------------------------------
  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  schema {
    attribute_data_type = "String"
    name                = "name"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # ---------------------------------------------------------------------------
  # Email Configuration — Use Cognito's built-in email sender
  # For production, configure SES for custom sender domain
  # ---------------------------------------------------------------------------
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # ---------------------------------------------------------------------------
  # Account Recovery — Allow password reset via verified email
  # ---------------------------------------------------------------------------
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Deletion protection — prevent accidental deletion (SOC 2 CC9)
  deletion_protection = "ACTIVE"

  tags = {
    Name = "${var.project_name}-user-pool"
  }
}

# =============================================================================
# Cognito User Pool Domain — Hosted login UI
# =============================================================================
# Provides a hosted sign-in page at:
#   https://<domain-prefix>.auth.<region>.amazoncognito.com
#
# This allows users to sign up, sign in, and reset passwords without
# building a custom authentication UI.
# =============================================================================
resource "aws_cognito_user_pool_domain" "app" {
  domain       = "${var.project_name}-auth"
  user_pool_id = aws_cognito_user_pool.app.id
}

# =============================================================================
# Cognito User Pool Client — Application OAuth2 client
# =============================================================================
# The client configuration defines how the Boardgame application interacts
# with Cognito for authentication. It specifies:
#   - Which OAuth2 flows are allowed
#   - Token validity periods
#   - Allowed scopes
#   - Callback URLs for redirects after sign-in
# =============================================================================
resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.app.id

  # ---------------------------------------------------------------------------
  # OAuth2 Configuration
  # ---------------------------------------------------------------------------
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  # Callback URLs — where Cognito redirects after sign-in/sign-out
  # Update these with your actual application URLs
  callback_urls = [
    "https://app.${var.domain_name}/callback",
    "http://localhost:8080/callback" # For local development
  ]
  logout_urls = [
    "https://app.${var.domain_name}/logout",
    "http://localhost:8080/logout"
  ]

  # ---------------------------------------------------------------------------
  # Token Configuration — JWT token validity periods
  # ---------------------------------------------------------------------------
  access_token_validity  = 1  # 1 hour
  id_token_validity      = 1  # 1 hour
  refresh_token_validity = 30 # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Do NOT generate a client secret — required for browser-based (SPA) clients
  generate_secret = false

  # Prevent user existence errors from leaking information
  prevent_user_existence_errors = "ENABLED"

  # Enable token revocation for security
  enable_token_revocation = true
}
