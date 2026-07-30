"""OIDC discovery, token exchange, and ID token validation."""

from __future__ import annotations

import base64
import hashlib
import logging
import secrets
from typing import Any, Dict, Optional, Tuple
from urllib.parse import urlencode

import jwt
import requests
from django.core.cache import cache
from jwt import PyJWKClient

logger = logging.getLogger(__name__)

DISCOVERY_CACHE_TTL = 60 * 60  # 1 hour
HTTP_TIMEOUT = 15


class OidcError(Exception):
    """Raised when OIDC protocol steps fail."""

    def __init__(self, code: str, detail: str = ""):
        self.code = code
        self.detail = detail or code
        super().__init__(self.detail)


def normalize_discovery_url(url: str) -> str:
    url = (url or "").strip().rstrip("/")
    if not url:
        return ""
    marker = "/.well-known/openid-configuration"
    if marker in url:
        return url
    return f"{url}{marker}"


def fetch_discovery(discovery_url: str) -> Dict[str, Any]:
    url = normalize_discovery_url(discovery_url)
    if not url:
        raise OidcError("invalid_config", "OIDC discovery URL is empty")
    cache_key = f"oidc:discovery:{hashlib.sha256(url.encode()).hexdigest()}"
    cached = cache.get(cache_key)
    if isinstance(cached, dict):
        return cached
    try:
        response = requests.get(url, timeout=HTTP_TIMEOUT)
        response.raise_for_status()
        data = response.json()
    except (requests.RequestException, ValueError) as exc:
        logger.warning("OIDC discovery failed for %s: %s", url, exc)
        raise OidcError("discovery_failed", "Could not load OIDC discovery document")
    if not isinstance(data, dict) or "authorization_endpoint" not in data:
        raise OidcError("discovery_failed", "Invalid OIDC discovery document")
    cache.set(cache_key, data, DISCOVERY_CACHE_TTL)
    return data


def generate_pkce_pair() -> Tuple[str, str]:
    """Return (code_verifier, code_challenge) using S256."""
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode("ascii")
    return verifier, challenge


def build_authorization_url(
    *,
    discovery: Dict[str, Any],
    client_id: str,
    redirect_uri: str,
    scope: str,
    state: str,
    nonce: str,
    code_challenge: str,
) -> str:
    endpoint = discovery["authorization_endpoint"]
    params = {
        "response_type": "code",
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "scope": scope,
        "state": state,
        "nonce": nonce,
        "code_challenge": code_challenge,
        "code_challenge_method": "S256",
    }
    sep = "&" if "?" in endpoint else "?"
    return f"{endpoint}{sep}{urlencode(params)}"


def exchange_code(
    *,
    discovery: Dict[str, Any],
    client_id: str,
    client_secret: str,
    code: str,
    redirect_uri: str,
    code_verifier: str,
) -> Dict[str, Any]:
    token_endpoint = discovery.get("token_endpoint")
    if not token_endpoint:
        raise OidcError("discovery_failed", "Discovery document has no token_endpoint")
    data = {
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": client_id,
        "code_verifier": code_verifier,
    }
    if client_secret:
        data["client_secret"] = client_secret
    try:
        response = requests.post(
            token_endpoint,
            data=data,
            headers={"Accept": "application/json"},
            timeout=HTTP_TIMEOUT,
        )
    except requests.RequestException as exc:
        logger.warning("OIDC token exchange request failed: %s", exc)
        raise OidcError("token_exchange_failed", "Could not reach identity provider")
    if response.status_code >= 400:
        logger.warning(
            "OIDC token exchange HTTP %s body_len=%s",
            response.status_code,
            len(response.content or b""),
        )
        raise OidcError("token_exchange_failed", "Identity provider rejected the code")
    try:
        payload = response.json()
    except ValueError:
        raise OidcError("token_exchange_failed", "Invalid token response")
    if not isinstance(payload, dict) or not payload.get("id_token"):
        raise OidcError("token_exchange_failed", "Token response missing id_token")
    return payload


def validate_id_token(
    *,
    id_token: str,
    discovery: Dict[str, Any],
    client_id: str,
    nonce: str,
) -> Dict[str, Any]:
    issuer = discovery.get("issuer")
    jwks_uri = discovery.get("jwks_uri")
    if not issuer or not jwks_uri:
        raise OidcError("discovery_failed", "Discovery missing issuer or jwks_uri")

    try:
        jwk_client = PyJWKClient(jwks_uri, cache_keys=True, lifespan=DISCOVERY_CACHE_TTL)
        signing_key = jwk_client.get_signing_key_from_jwt(id_token)
        claims = jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256", "RS384", "RS512", "ES256", "ES384", "ES512"],
            audience=client_id,
            issuer=issuer,
            leeway=60,
            options={"require": ["exp", "iat", "sub"]},
        )
    except jwt.PyJWTError as exc:
        logger.warning("OIDC id_token validation failed: %s", exc)
        raise OidcError("invalid_id_token", "ID token validation failed")

    token_nonce = claims.get("nonce")
    if nonce and token_nonce != nonce:
        raise OidcError("invalid_id_token", "ID token nonce mismatch")
    return claims


def fetch_userinfo(
    *,
    discovery: Dict[str, Any],
    access_token: str,
) -> Dict[str, Any]:
    endpoint = discovery.get("userinfo_endpoint")
    if not endpoint or not access_token:
        return {}
    try:
        response = requests.get(
            endpoint,
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/json",
            },
            timeout=HTTP_TIMEOUT,
        )
        response.raise_for_status()
        data = response.json()
        return data if isinstance(data, dict) else {}
    except (requests.RequestException, ValueError) as exc:
        logger.warning("OIDC userinfo request failed: %s", exc)
        return {}


def extract_username(claims: Dict[str, Any], claim_name: str) -> str:
    """Pull username from claims; support nested dotted paths lightly."""
    if not claim_name:
        claim_name = "preferred_username"
    value = claims.get(claim_name)
    if value is None and "." in claim_name:
        # simple one-level nesting only
        head, tail = claim_name.split(".", 1)
        nested = claims.get(head)
        if isinstance(nested, dict):
            value = nested.get(tail)
    if value is None:
        return ""
    return str(value).strip()
