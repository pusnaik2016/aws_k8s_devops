"""
Secrets Helper — Secure Runtime Credential Access
===================================================
Wraps dbutils.secrets.get() with environment-aware scope resolution.
NEVER logs, prints, or exposes secret values in any output.

COMPLIANCE: SOC 2 CC6.1 — No hardcoded credentials
"""

from typing import Optional


def get_secret(scope: str, key: str, dbutils=None) -> str:
    """
    Fetch a secret from Databricks Secret Scope at runtime.

    Args:
        scope: Databricks secret scope name (e.g., 'aws-sm-scope', 'azure-kv-scope')
        key:   Secret key name (e.g., 'redshift-dw-password')
        dbutils: Databricks dbutils reference (injected for testability)

    Returns:
        Secret value as string

    Raises:
        ValueError: If scope or key is empty
        RuntimeError: If secret retrieval fails
    """
    if not scope or not scope.strip():
        raise ValueError("Secret scope name cannot be empty")
    if not key or not key.strip():
        raise ValueError("Secret key name cannot be empty")

    try:
        if dbutils is None:
            # Running in Databricks — use global dbutils
            # pylint: disable=undefined-variable
            value = globals()["dbutils"].secrets.get(scope=scope, key=key)  # noqa: F821
        else:
            value = dbutils.secrets.get(scope=scope, key=key)

        if not value:
            raise RuntimeError(f"Secret '{key}' in scope '{scope}' returned empty value")

        # COMPLIANCE: Never log the actual value
        print(f"[SECRETS] Successfully retrieved secret: scope='{scope}', key='{key}'")
        return value

    except Exception as e:
        # Log the error without exposing secret details
        error_msg = f"Failed to retrieve secret: scope='{scope}', key='{key}'"
        print(f"[SECRETS] ERROR: {error_msg}")
        raise RuntimeError(error_msg) from e


def get_connection_string(
    scope: str,
    host_key: str,
    port_key: str,
    database_key: str,
    username_key: str,
    password_key: str,
    dbutils=None,
    driver: str = "postgresql"
) -> str:
    """
    Build a JDBC connection string from individual secrets.

    Returns:
        JDBC URL string (password embedded — handle with care)
    """
    host = get_secret(scope, host_key, dbutils)
    port = get_secret(scope, port_key, dbutils)
    database = get_secret(scope, database_key, dbutils)
    username = get_secret(scope, username_key, dbutils)
    password = get_secret(scope, password_key, dbutils)

    return f"jdbc:{driver}://{host}:{port}/{database}?user={username}&password={password}"
