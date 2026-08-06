"""H4 — outbound SSRF guards."""

import ipaddress
from unittest import mock

import pytest
import requests

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


def test_is_url_safe_helper(block_private, mocker):
    mocker.patch.object(
        ssrf,
        "_resolve_ips",
        return_value={ipaddress.ip_address("1.2.3.4")},
    )
    assert ssrf.is_url_safe("https://ok.example/") is True
    assert ssrf.is_url_safe("http://127.0.0.1/") is False
