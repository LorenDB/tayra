"""H4 — outbound SSRF guards."""

import ipaddress
import socket
from unittest import mock
from urllib.parse import urlparse

import pytest

from funkwhale_api.common import session as session_mod
from funkwhale_api.common import ssrf


@pytest.fixture
def block_private(settings):
    settings.EXTERNAL_REQUESTS_BLOCK_PRIVATE_IPS = True


@pytest.mark.parametrize(
    "url",
    [
        "http://127.0.0.1/",
        "http://127.0.0.1:8080/admin",
        "http://localhost/secret",
        "http://[::1]/",
        "http://10.0.0.1/",
        "http://192.168.1.1/",
        "http://172.16.0.5/",
        "http://169.254.169.254/latest/meta-data/",
        "http://metadata.google.internal/",
        "file:///etc/passwd",
        "ftp://example.com/",
        "gopher://example.com/",
    ],
)
def test_validate_blocks_private_and_non_http(url, block_private):
    with pytest.raises(ssrf.UnsafeURLError):
        ssrf.validate_external_url(url)


@pytest.mark.parametrize(
    "url",
    [
        "https://example.com/feed.xml",
        "http://example.com:8080/path",
        "https://cdn.example.org/cover.jpg",
    ],
)
def test_validate_allows_public_http(url, block_private, mocker):
    public = ipaddress.ip_address("93.184.216.34")

    def fake_resolve(hostname, port):
        return {public}

    mocker.patch.object(ssrf, "_resolve_ips", side_effect=fake_resolve)
    assert ssrf.validate_external_url(url) == url


def test_validate_blocks_dns_to_private(block_private, mocker):
    mocker.patch.object(
        ssrf,
        "_resolve_ips",
        return_value={ipaddress.ip_address("10.1.2.3")},
    )
    with pytest.raises(ssrf.UnsafeURLError):
        ssrf.validate_external_url("https://evil.example/internal")


def test_webfinger_domain_checked(block_private, mocker):
    mocker.patch.object(
        ssrf,
        "_resolve_ips",
        return_value={ipaddress.ip_address("10.0.0.8")},
    )
    with pytest.raises(ssrf.UnsafeURLError):
        ssrf.validate_external_url(
            "webfinger://user@internal.lan", allow_webfinger=True
        )


def test_redirect_to_private_ip_blocked(block_private, mocker, r_mock):
    public = ipaddress.ip_address("93.184.216.34")

    def fake_resolve(hostname, port):
        if hostname == "public.example":
            return {public}
        raise ssrf.UnsafeURLError("blocked")

    mocker.patch.object(ssrf, "_resolve_ips", side_effect=fake_resolve)

    r_mock.get(
        "https://public.example/start",
        status_code=302,
        headers={"Location": "http://127.0.0.1/secret"},
    )

    s = session_mod.get_session()
    # Force SSRF path even if session setting is read at request time
    with pytest.raises(ssrf.UnsafeURLError):
        ssrf.safe_request(s, "GET", "https://public.example/start")


def _quiet_response(url, *, redirect_to=None):
    resp = mock.Mock()
    resp.url = url
    resp.history = []
    if redirect_to:
        resp.is_redirect = True
        resp.is_permanent_redirect = False
        resp.status_code = 302
        resp.headers = {"Location": redirect_to}
    else:
        resp.is_redirect = False
        resp.is_permanent_redirect = False
        resp.status_code = 200
        resp.headers = {}
    return resp


def test_safe_request_pins_idna2008_connect_label(block_private, mocker):
    """urllib3 resolves the idna-package A-label, not stdlib IDNA2003.

    ``straße.example`` is ``strasse.example`` via ``str.encode('idna')`` and
    ``xn--strae-oqa.example`` via the idna package. The connect lookup must
    still return the address that passed validation.
    """
    import idna

    public = ipaddress.ip_address("93.184.216.34")
    private = ipaddress.ip_address("127.0.0.1")
    phase = {"connect": False}
    unicode_host = "straße.example"
    stdlib_label = unicode_host.encode("idna").decode("ascii")
    connect_label = ".".join(
        idna.encode(part, strict=True, std3_rules=True).decode("ascii")
        if any(ord(char) >= 128 for char in part)
        else part
        for part in unicode_host.split(".")
    )
    assert connect_label != stdlib_label

    def fake_resolve(hostname, port):
        if phase["connect"]:
            return {private}
        return {public}

    mocker.patch.object(ssrf, "_resolve_ips", side_effect=fake_resolve)
    real = mocker.patch.object(
        ssrf,
        "_real_getaddrinfo",
        return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443))],
    )
    seen = {}

    def raw(session, method, url, **kwargs):
        phase["connect"] = True
        assert ssrf._resolve_ips(connect_label, 443) == {private}
        infos = socket.getaddrinfo(connect_label, 443)
        seen["addrs"] = [item[4][0] for item in infos]
        return _quiet_response(url)

    mocker.patch.object(ssrf, "_session_raw_request", side_effect=raw)
    ssrf.safe_request(mock.Mock(), "GET", "https://straße.example/feed")
    assert seen["addrs"] == ["93.184.216.34"]
    assert real.call_count == 0


def test_safe_request_pins_validated_address(block_private, mocker):
    """Connect uses the IP that passed validation, not a later DNS answer."""
    public = ipaddress.ip_address("93.184.216.34")
    private = ipaddress.ip_address("127.0.0.1")
    phase = {"connect": False}

    def fake_resolve(hostname, port):
        if phase["connect"]:
            return {private}
        return {public}

    mocker.patch.object(ssrf, "_resolve_ips", side_effect=fake_resolve)
    seen = {}

    def raw(session, method, url, **kwargs):
        phase["connect"] = True
        assert ssrf._resolve_ips("rebind.example", 443) == {private}
        infos = socket.getaddrinfo("rebind.example", 443)
        seen["addrs"] = [item[4][0] for item in infos]
        return _quiet_response(url)

    mocker.patch.object(ssrf, "_session_raw_request", side_effect=raw)
    ssrf.safe_request(mock.Mock(), "GET", "https://rebind.example/feed")
    assert seen["addrs"] == ["93.184.216.34"]


def test_safe_request_repins_each_redirect(block_private, mocker):
    first = ipaddress.ip_address("93.184.216.34")
    second = ipaddress.ip_address("1.1.1.1")

    def fake_resolve(hostname, port):
        if hostname == "a.example":
            return {first}
        if hostname == "b.example":
            return {second}
        raise AssertionError(hostname)

    mocker.patch.object(ssrf, "_resolve_ips", side_effect=fake_resolve)
    seen = []

    def raw(session, method, url, **kwargs):
        host = urlparse(url).hostname
        addr = socket.getaddrinfo(host, 443)[0][4][0]
        seen.append((host, addr))
        if host == "a.example":
            return _quiet_response(url, redirect_to="https://b.example/next")
        return _quiet_response(url)

    mocker.patch.object(ssrf, "_session_raw_request", side_effect=raw)
    ssrf.safe_request(mock.Mock(), "GET", "https://a.example/start")
    assert seen == [("a.example", "93.184.216.34"), ("b.example", "1.1.1.1")]


def test_safe_request_clears_pin_after_return(block_private, mocker):
    public = ipaddress.ip_address("93.184.216.34")
    mocker.patch.object(ssrf, "_resolve_ips", return_value={public})

    def raw(session, method, url, **kwargs):
        return _quiet_response(url)

    mocker.patch.object(ssrf, "_session_raw_request", side_effect=raw)
    sentinel = [("sentinel",)]
    real = mocker.patch.object(ssrf, "_real_getaddrinfo", return_value=sentinel)
    ssrf.safe_request(mock.Mock(), "GET", "https://rebind.example/a")
    real.reset_mock()
    assert socket.getaddrinfo("rebind.example", 80) == sentinel
    assert real.called


def test_is_url_safe_helper(block_private, mocker):
    mocker.patch.object(
        ssrf,
        "_resolve_ips",
        return_value={ipaddress.ip_address("1.2.3.4")},
    )
    assert ssrf.is_url_safe("https://ok.example/") is True
    assert ssrf.is_url_safe("http://127.0.0.1/") is False
