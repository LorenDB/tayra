import os

os.environ.setdefault("FUNKWHALE_URL", "http://funkwhale.dev")

from .common import *  # noqa

DEBUG = True
SECRET_KEY = "a_super_secret_key!"
TYPESENSE_API_KEY = "apikey"
