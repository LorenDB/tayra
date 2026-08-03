"""Allowed client_redirect targets for the OIDC SSO handoff (H3).

Open redirects let an attacker complete IdP login and land the one-time
exchange code on an attacker-controlled origin. Only the pod origin,
configured extras, OOB URNs, and the first-party ``tayra:`` app scheme are
accepted.
"""

from __future__ import annotations

import logging
from typing import Iterable, List, Optional, Set, Tuple
from urllib.parse import urlsplit

from django.conf import settings

logger = logging.getLogger(__name__)

OOB_REDIRECTS = frozenset(
    {
        "urn:ietf:wg:oauth:2.0:oob",
        "urn:ietf:wg:oauth:2.0:oob:auto",
    }
)

# First-party native / desktop custom scheme (path optional).
_APP_SCHEMES = frozenset({"tayra"})


def _origin_tuple(scheme: str, netloc: str) -> Tuple[str, str]:
    return (scheme.lower(), netloc.lower())


def _origin_from_url(url: str) -> Optional[Tuple[str, str]]:
    try:
        parsed = urlsplit(url)
    except Exception:
        return None
    if not parsed.scheme or not parsed.netloc:
        return None
    if "@" in parsed.netloc:
        return None
    return _origin_tuple(parsed.scheme, parsed.netloc)


def allowed_redirect_origins() -> Set[Tuple[str, str]]:
    """Origins that may receive the post-IdP exchange code redirect."""
    origins: Set[Tuple[str, str]] = set()

    fw = (getattr(settings, "FUNKWHALE_URL", "") or "").strip()
    origin = _origin_from_url(fw)
    if origin:
        origins.add(origin)

    spa = (getattr(settings, "FUNKWHALE_SPA_HTML_ROOT", "") or "").strip()
    if spa:
        origin = _origin_from_url(spa)
        if origin:
            origins.add(origin)

    extra = getattr(settings, "OIDC_CLIENT_REDIRECT_ORIGINS", None) or []
    if isinstance(extra, str):
        extra = [part.strip() for part in extra.split(",") if part.strip()]
    if isinstance(extra, Iterable):
        for entry in extra:
            if not entry:
                continue
            text = str(entry).strip()
            if not text:
                continue
            # Allow bare origins or full URLs.
            if "://" not in text:
                text = "https://" + text
            origin = _origin_from_url(text)
            if origin:
                origins.add(origin)

    return origins


def is_allowed_client_redirect(value: str) -> bool:
    """Return True when ``value`` is a safe post-SSO client redirect target."""
    if not value or not isinstance(value, str):
        return False
    value = value.strip()
    if not value:
        return False

    if value in OOB_REDIRECTS:
        return True

    try:
        parsed = urlsplit(value)
    except Exception:
        return False

    scheme = (parsed.scheme or "").lower()
    if not scheme:
        return False

    # Block dangerous schemes explicitly.
    if scheme in ("javascript", "data", "file", "vbscript", "blob"):
        return False

    # First-party app deep link (e.g. tayra://sso/callback).
    if scheme in _APP_SCHEMES:
        # Reject credentials in netloc if present.
        if parsed.netloc and "@" in parsed.netloc:
            return False
        return True

    if scheme not in ("http", "https"):
        return False

    if not parsed.netloc or "@" in parsed.netloc:
        return False

    candidate = _origin_tuple(scheme, parsed.netloc)
    if candidate in allowed_redirect_origins():
        return True

    return False


def describe_allowed_redirects() -> List[str]:
    """Human-readable list for logs / errors (no secrets)."""
    items = sorted(f"{s}://{h}" for s, h in allowed_redirect_origins())
    items.extend(sorted(OOB_REDIRECTS))
    items.append("tayra://…")
    return items
