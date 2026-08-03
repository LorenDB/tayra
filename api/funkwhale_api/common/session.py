import requests
from django.conf import settings

import funkwhale_api

from . import ssrf


class FunkwhaleSession(requests.Session):
    """HTTP session for outbound requests with TLS defaults and SSRF guards."""

    def request(self, method, url, **kwargs):
        kwargs.setdefault("verify", settings.EXTERNAL_REQUESTS_VERIFY_SSL)
        kwargs.setdefault("timeout", settings.EXTERNAL_REQUESTS_TIMEOUT)
        # H4: block private/loopback/metadata targets (incl. redirect hops).
        if getattr(settings, "EXTERNAL_REQUESTS_BLOCK_PRIVATE_IPS", True):
            # safe_request calls Session.request with allow_redirects=False;
            # avoid recursion by using the unbound parent for the actual hop.
            return ssrf.safe_request(self, method, url, **kwargs)
        return super().request(method, url, **kwargs)

    def _raw_request(self, method, url, **kwargs):
        """Bypass SSRF redirect loop; used only by :func:`ssrf.safe_request`."""
        return super().request(method, url, **kwargs)


def get_user_agent():
    return "python-requests (funkwhale/{}; +{})".format(
        funkwhale_api.__version__, settings.FUNKWHALE_URL
    )


def get_session():
    s = FunkwhaleSession()
    s.headers["User-Agent"] = get_user_agent()
    return s
