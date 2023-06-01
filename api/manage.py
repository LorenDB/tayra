#!/usr/bin/env python3

import warnings

from funkwhale_api.main import main

warnings.warn(
    DeprecationWarning(
        "the './manage.py' script has been deprecated, please use the 'funkwhale-manage' "
        "entrypoint instead (e.g. 'funkwhale-manage migrate')"
    )
)

if __name__ == "__main__":
    SystemExit(main())
