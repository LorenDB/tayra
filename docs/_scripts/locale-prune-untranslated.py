#!/usr/bin/env python3

import os
from subprocess import check_output


def main() -> int:
    output = check_output(["poetry", "run", "sphinx-intl", "stat"], text=True)
    for line in output.splitlines():
        path, _, comment = line.partition(":")
        if "0 untranslated." in comment:
            print(f"removing untranslated po file: {path}")
            os.unlink(path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
