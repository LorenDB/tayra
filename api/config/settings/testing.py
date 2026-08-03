import os

os.environ.setdefault("FUNKWHALE_URL", "http://funkwhale.dev")

from .common import *  # noqa

DEBUG = True
SECRET_KEY = "a_super_secret_key!"
TYPESENSE_API_KEY = "apikey"
# Fake hostnames in HTTP mocks would fail SSRF DNS checks; dedicated SSRF
# tests re-enable EXTERNAL_REQUESTS_BLOCK_PRIVATE_IPS explicitly.
EXTERNAL_REQUESTS_BLOCK_PRIVATE_IPS = False
