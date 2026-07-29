"""Client → server password transport hashing for first-party login.

The Tayra client never sends the account password in plaintext on
``POST /api/v1/users/token/``. It sends a domain-separated SHA-256 hex
digest instead so request bodies (DevTools, reverse-proxy logs, etc.) do
not expose the real password.

Storage still uses Django's password hashers. On ``set_password`` the
transport digest is what gets passed into Django (i.e. the server stores
``django_hash(transport_hash(password))``). ``check_password`` accepts
either the original plaintext (admin / CLI / legacy rows) or a transport
digest (the token login path).
"""

from __future__ import annotations

import hashlib
import re

# Domain separation so this digest is not a bare password hash reusable
# against other systems or unsalted SHA-256 tables.
_DOMAIN_PREFIX = b"tayra-login-v1\0"

# Lowercase hex SHA-256.
TRANSPORT_HASH_RE = re.compile(r"\A[0-9a-f]{64}\Z")


def hash_password_for_transport(password: str) -> str:
    """Return the hex digest the client must send (and that we store via Django)."""
    if not isinstance(password, str):
        raise TypeError("password must be str")
    return hashlib.sha256(_DOMAIN_PREFIX + password.encode("utf-8")).hexdigest()


def is_transport_password_hash(value: str) -> bool:
    """True if ``value`` looks like a transport password digest."""
    return isinstance(value, str) and bool(TRANSPORT_HASH_RE.fullmatch(value))
