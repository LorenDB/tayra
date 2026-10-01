"""nginx add_header locations must still send X-Content-Type-Options."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TEMPLATES = (
    ROOT / "front" / "docker" / "funkwhale.conf.template",
    ROOT / "deploy" / "nginx.template",
)

_NOSNIFF = 'add_header X-Content-Type-Options "nosniff" always;'
_SERVER = re.compile(r"^\s*server\s*(\{|$)")
_LOCATION = re.compile(r"^\s*location\s+\S")


def _brace_blocks(text, opener):
    """Yield brace-balanced blocks whose first line matches *opener*."""
    lines = text.splitlines(keepends=True)
    index = 0
    total = len(lines)
    while index < total:
        if not opener.match(lines[index]):
            index += 1
            continue
        depth = 0
        started = False
        buf = []
        while index < total:
            line = lines[index]
            buf.append(line)
            depth += line.count("{") - line.count("}")
            if "{" in line:
                started = True
            index += 1
            if started and depth <= 0:
                break
        yield "".join(buf)


def test_nginx_templates_send_nosniff_where_add_header_is_set():
    for path in TEMPLATES:
        text = path.read_text()
        servers = list(_brace_blocks(text, _SERVER))
        assert servers, path
        saw_security_server = False
        for server in servers:
            location_at = None
            for line in server.splitlines(keepends=True):
                if _LOCATION.match(line):
                    location_at = server.find(line)
                    break
            preamble = server if location_at is None else server[:location_at]
            if "add_header" not in preamble:
                continue
            saw_security_server = True
            assert _NOSNIFF in preamble, path
        assert saw_security_server, path
        for location in _brace_blocks(text, _LOCATION):
            if "add_header" not in location:
                continue
            assert _NOSNIFF in location, (path.name, location.splitlines()[0].strip())
