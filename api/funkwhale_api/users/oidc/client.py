"""OIDC discovery, token exchange, and ID token validation."""

from __future__ import annotations

import base64
import hashlib
import json
import logging
import secrets
from typing import Any, Dict, Optional, Tuple
from urllib.parse import urlencode

import jwt
import requests
from django.core.cache import cache

from funkwhale_api.common import session as http_session
from funkwhale_api.common.ssrf import UnsafeURLError, validate_external_url

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


def _oidc_get(url: str) -> requests.Response:
    """GET *url* with SSRF checks (private IPs / metadata / redirect hops)."""
    try:
        validate_external_url(url)
    except UnsafeURLError as exc:
        logger.warning("OIDC blocked unsafe URL %s: %s", url, exc)
        raise OidcError("unsafe_url", "OIDC endpoint URL is not allowed") from exc
    try:
        return http_session.get_session().get(url, timeout=HTTP_TIMEOUT)
    except UnsafeURLError as exc:
        logger.warning("OIDC blocked unsafe URL during request %s: %s", url, exc)
        raise OidcError("unsafe_url", "OIDC endpoint URL is not allowed") from exc
    except requests.RequestException as exc:
        logger.warning("OIDC HTTP GET failed for %s: %s", url, exc)
        raise OidcError("http_failed", "Could not reach OIDC endpoint") from exc


def _oidc_post(url: str, data: dict) -> requests.Response:
    """POST *url* with SSRF checks."""
    try:
        validate_external_url(url)
    except UnsafeURLError as exc:
        logger.warning("OIDC blocked unsafe URL %s: %s", url, exc)
        raise OidcError("unsafe_url", "OIDC endpoint URL is not allowed") from exc
    try:
        return http_session.get_session().post(
            url,
            data=data,
            headers={"Accept": "application/json"},
            timeout=HTTP_TIMEOUT,
        )
    except UnsafeURLError as exc:
        logger.warning("OIDC blocked unsafe URL during request %s: %s", url, exc)
        raise OidcError("unsafe_url", "OIDC endpoint URL is not allowed") from exc
    except requests.RequestException as exc:
        logger.warning("OIDC HTTP POST failed for %s: %s", url, exc)
        raise OidcError("http_failed", "Could not reach OIDC endpoint") from exc


def fetch_discovery(discovery_url: str) -> Dict[str, Any]:
    url = normalize_discovery_url(discovery_url)
    if not url:
        raise OidcError("invalid_config", "OIDC discovery URL is empty")
    cache_key = f"oidc:discovery:{hashlib.sha256(url.encode()).hexdigest()}"
    cached = cache.get(cache_key)
    if isinstance(cached, dict):
        return cached
    try:
        response = _oidc_get(url)
        response.raise_for_status()
        data = response.json()
    except OidcError:
        raise
    except (requests.RequestException, ValueError) as exc:
        logger.warning("OIDC discovery failed for %s: %s", url, exc)
        raise OidcError("discovery_failed", "Could not load OIDC discovery document")
    if not isinstance(data, dict) or "authorization_endpoint" not in data:
        raise OidcError("discovery_failed", "Invalid OIDC discovery document")
    # Validate endpoints before caching so a malicious discovery doc cannot
    # later point token/jwks/userinfo at an internal address.
    for key in ("token_endpoint", "jwks_uri", "userinfo_endpoint"):
        endpoint = data.get(key)
        if not endpoint:
            continue
        try:
            validate_external_url(str(endpoint))
        except UnsafeURLError as exc:
            logger.warning(
                "OIDC discovery endpoint %s blocked (%s): %s", key, endpoint, exc
            )
            raise OidcError(
                "unsafe_url", f"OIDC discovery {key} is not allowed"
            ) from exc
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
        response = _oidc_post(str(token_endpoint), data)
    except OidcError:
        raise
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


def _signing_key_from_jwks(jwks: Dict[str, Any], id_token: str):
    """Resolve the JWT signing key from a pre-fetched JWKS document (no HTTP)."""
    try:
        header = jwt.get_unverified_header(id_token)
    except jwt.PyJWTError as exc:
        raise OidcError("invalid_id_token", "Malformed ID token header") from exc
    kid = header.get("kid")
    keys = jwks.get("keys") if isinstance(jwks, dict) else None
    if not isinstance(keys, list) or not keys:
        raise OidcError("discovery_failed", "JWKS document has no keys")
    matching = None
    for entry in keys:
        if not isinstance(entry, dict):
            continue
        if kid is None or entry.get("kid") == kid:
            matching = entry
            break
    if matching is None:
        raise OidcError("invalid_id_token", "No matching JWKS key for ID token")
    try:
        return jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(matching))
    except Exception:
        try:
            return jwt.algorithms.ECAlgorithm.from_jwk(json.dumps(matching))
        except Exception as exc:
            raise OidcError(
                "invalid_id_token", "Could not load ID token signing key"
            ) from exc


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

    # Fetch JWKS through the SSRF-safe session (never PyJWKClient's raw HTTP).
    cache_key = f"oidc:jwks:{hashlib.sha256(str(jwks_uri).encode()).hexdigest()}"
    jwks = cache.get(cache_key)
    if not isinstance(jwks, dict):
        try:
            response = _oidc_get(str(jwks_uri))
            response.raise_for_status()
            jwks = response.json()
        except OidcError:
            raise
        except (requests.RequestException, ValueError) as exc:
            logger.warning("OIDC JWKS fetch failed: %s", exc)
            raise OidcError("discovery_failed", "Could not load OIDC JWKS") from exc
        if not isinstance(jwks, dict):
            raise OidcError("discovery_failed", "Invalid JWKS document")
        cache.set(cache_key, jwks, DISCOVERY_CACHE_TTL)

    try:
        signing_key = _signing_key_from_jwks(jwks, id_token)
        claims = jwt.decode(
            id_token,
            signing_key,
            algorithms=["RS256", "RS384", "RS512", "ES256", "ES384", "ES512"],
            audience=client_id,
            issuer=issuer,
            leeway=60,
            options={"require": ["exp", "iat", "sub"]},
        )
    except OidcError:
        raise
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
        validate_external_url(str(endpoint))
        response = http_session.get_session().get(
            str(endpoint),
            headers={
                "Authorization": f"Bearer {access_token}",
                "Accept": "application/json",
            },
            timeout=HTTP_TIMEOUT,
        )
        response.raise_for_status()
        data = response.json()
        return data if isinstance(data, dict) else {}
    except UnsafeURLError as exc:
        logger.warning("OIDC userinfo URL blocked: %s", exc)
        return {}
    except (requests.RequestException, ValueError, OidcError) as exc:
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
