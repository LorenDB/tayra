"""Outbound URL validation to mitigate SSRF (H4).

User-controlled and remote-object fetches must not reach private, loopback,
link-local, or cloud-metadata addresses — including after DNS resolution and
across HTTP redirects.
"""

from __future__ import annotations

import ipaddress
import socket
from typing import Optional, Set
from urllib.parse import urljoin, urlparse

import requests
from django.conf import settings

# Schemes permitted for server-side outbound fetches.
_ALLOWED_SCHEMES = frozenset({"http", "https"})

# Hostnames that always resolve (or are treated as) loopback / local.
_BLOCKED_HOSTNAMES = frozenset(
    {
        "localhost",
        "localhost.localdomain",
        "ip6-localhost",
        "ip6-loopback",
        "metadata",
        "metadata.google.internal",
    }
)

# AWS / cloud metadata common names (blocked even if DNS is public).
_METADATA_HOSTNAMES = frozenset(
    {
        "169.254.169.254",
        "metadata.google.internal",
        "metadata",
    }
)


class UnsafeURLError(ValueError):
    """Raised when a URL is not safe for outbound server-side fetch."""

    def __init__(self, message: str = "URL is not allowed for outbound requests"):
        super().__init__(message)
        self.message = message


def _block_private() -> bool:
    return bool(getattr(settings, "EXTERNAL_REQUESTS_BLOCK_PRIVATE_IPS", True))


def _parse_ip(host: str) -> Optional[ipaddress._BaseAddress]:
    try:
        # Strip IPv6 brackets if present.
        if host.startswith("[") and host.endswith("]"):
            host = host[1:-1]
        return ipaddress.ip_address(host)
    except ValueError:
        return None


def _is_blocked_ip(ip: ipaddress._BaseAddress) -> bool:
    """Return True if *ip* must not be contacted by outbound fetches."""
    if ip.is_private:
        return True
    if ip.is_loopback:
        return True
    if ip.is_link_local:
        return True
    if ip.is_reserved:
        return True
    if ip.is_multicast:
        return True
    if ip.is_unspecified:
        return True
    # Cloud metadata (IPv4 link-local already covered; keep explicit).
    if ip == ipaddress.ip_address("169.254.169.254"):
        return True
    # IPv6 unique local (fc00::/7) — covered by is_private on modern Python.
    return False


def _hostname_blocked(hostname: str) -> bool:
    host = (hostname or "").strip().lower().rstrip(".")
    if not host:
        return True
    if host in _BLOCKED_HOSTNAMES or host in _METADATA_HOSTNAMES:
        return True
    # Reject trailing .local / .localhost / .internal (mDNS / internal zones).
    if host.endswith(".local") or host.endswith(".localhost") or host.endswith(
        ".internal"
    ):
        return True
    return False


def _resolve_ips(hostname: str, port: int) -> Set[ipaddress._BaseAddress]:
    """Resolve *hostname* to a set of IP addresses (A + AAAA)."""
    ips: Set[ipaddress._BaseAddress] = set()
    try:
        for family, _type, _proto, _canon, sockaddr in socket.getaddrinfo(
            hostname, port, type=socket.SOCK_STREAM
        ):
            addr = sockaddr[0]
            ip = _parse_ip(addr)
            if ip is not None:
                ips.add(ip)
    except socket.gaierror as exc:
        raise UnsafeURLError(f"Cannot resolve host for outbound request: {hostname}") from exc
    if not ips:
        raise UnsafeURLError(f"No addresses resolved for host: {hostname}")
    return ips


def validate_external_url(url: str, *, allow_webfinger: bool = False) -> str:
    """Validate *url* for server-side outbound HTTP(S) fetch.

    Returns the (stripped) URL on success.
    Raises :class:`UnsafeURLError` when the URL must not be fetched.
    """
    if not url or not isinstance(url, str):
        raise UnsafeURLError("Missing URL")

    url = url.strip()
    if allow_webfinger and url.startswith("webfinger://"):
        # Validate the acct domain only; the subsequent HTTPS hop is re-checked.
        resource = url[len("webfinger://") :]
        # resource is typically user@domain
        if "@" in resource:
            domain = resource.rsplit("@", 1)[-1]
        else:
            domain = resource
        domain = domain.strip().lower()
        if _hostname_blocked(domain):
            raise UnsafeURLError("Webfinger domain is not allowed")
        if not _block_private():
            return url
        # Domain may be an IP literal.
        ip = _parse_ip(domain)
        if ip is not None and _is_blocked_ip(ip):
            raise UnsafeURLError("Webfinger domain resolves to a blocked address")
        if ip is None:
            for resolved in _resolve_ips(domain, 443):
                if _is_blocked_ip(resolved):
                    raise UnsafeURLError(
                        "Webfinger domain resolves to a blocked address"
                    )
        return url

    parsed = urlparse(url)
    scheme = (parsed.scheme or "").lower()
    if scheme not in _ALLOWED_SCHEMES:
        raise UnsafeURLError(f"URL scheme not allowed: {scheme or '(none)'}")

    hostname = parsed.hostname
    if not hostname:
        raise UnsafeURLError("URL has no hostname")

    if _hostname_blocked(hostname):
        raise UnsafeURLError("Hostname is not allowed for outbound requests")

    if not _block_private():
        return url

    port = parsed.port or (443 if scheme == "https" else 80)
    ip_literal = _parse_ip(hostname)
    if ip_literal is not None:
        if _is_blocked_ip(ip_literal):
            raise UnsafeURLError("URL points to a blocked IP address")
        return url

    for resolved in _resolve_ips(hostname, port):
        if _is_blocked_ip(resolved):
            raise UnsafeURLError("URL hostname resolves to a blocked IP address")

    return url


def _session_raw_request(session, method: str, url: str, **kwargs):
    """Issue one hop without re-entering SSRF redirect handling."""
    raw = getattr(session, "_raw_request", None)
    if callable(raw):
        return raw(method, url, **kwargs)
    # Plain requests.Session (or tests): use the unbound base implementation.
    return requests.Session.request(session, method, url, **kwargs)


def safe_request(session, method: str, url: str, **kwargs):
    """Perform an HTTP request after SSRF checks, re-validating redirects.

    *session* is a :class:`requests.Session` (or compatible). Auto-redirects
    are disabled; each ``Location`` is validated before the next hop.
    """
    max_redirects = int(kwargs.pop("max_redirects", 5))
    # Caller may have set allow_redirects; we always manage redirects ourselves.
    kwargs.pop("allow_redirects", None)

    current = validate_external_url(url)
    history = []

    for _ in range(max_redirects + 1):
        response = _session_raw_request(
            session, method, current, allow_redirects=False, **kwargs
        )
        # Attach redirect history like requests does.
        if history:
            response.history = list(history)

        if response.is_redirect or response.is_permanent_redirect:
            location = response.headers.get("Location")
            if not location:
                return response
            # Relative redirects resolve against the current URL.
            next_url = (
                urljoin(response.url, location) if response.url else location
            )
            try:
                current = validate_external_url(next_url)
            except UnsafeURLError:
                response.close()
                raise
            history.append(response)
            # RFC: 303 switches to GET; 301/302 historically do for browsers.
            if response.status_code in (301, 302, 303) and method.upper() != "HEAD":
                method = "GET"
                # Drop body on method change.
                kwargs.pop("data", None)
                kwargs.pop("json", None)
                kwargs.pop("files", None)
            continue

        return response

    raise UnsafeURLError("Too many redirects for outbound request")



def is_url_safe(url: str, *, allow_webfinger: bool = False) -> bool:
    """Boolean wrapper around :func:`validate_external_url`."""
    try:
        validate_external_url(url, allow_webfinger=allow_webfinger)
        return True
    except UnsafeURLError:
        return False
