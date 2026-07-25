"""Sensitive preference key denylist (superset of Tayra export rules)."""

# Exact known credential keys (also covered by pattern rules; listed for clarity).
KNOWN_SENSITIVE_KEYS = frozenset(
    {
        "access_token",
        "refresh_token",
        "client_secret",
        "api_key",
        "groq_api_key",
        "open_router_api_key",
        "openrouter_api_key",
        "custom_endpoint_api_key",
        "nc_app_password",
    }
)


def is_sensitive_key(key: str) -> bool:
    """
    Return True if the preference key must be rejected server-side.

    Case-insensitive. Superset of Tayra ``_isSensitiveSettingsKey`` so AI
    ``*_api_key`` and related credentials cannot be stored even when the
    client export path misses them.
    """
    if not isinstance(key, str) or not key:
        return True

    k = key.lower()

    # 1. Substring denylist
    if "token" in k or "password" in k or "secret" in k:
        return True

    # 2. api_key patterns (exact, suffix, or compacted "apikey")
    if k == "api_key" or k.endswith("_api_key") or "apikey" in k:
        return True

    # 3. Known AI / OAuth credential keys
    if k in KNOWN_SENSITIVE_KEYS:
        return True

    # 4. Nextcloud: nc_* keys that look like credentials
    # password/token/secret already caught above; also reject nc_*login*
    if k.startswith("nc_") and "login" in k:
        return True

    return False
