#!/usr/bin/env python3

import json
import logging
from argparse import ArgumentParser
from functools import reduce
from operator import getitem
from subprocess import check_output
from typing import Dict, List

from packaging.version import InvalidVersion, Version

logger = logging.getLogger(__name__)


def get_releases() -> List[Dict[str, str]]:
    """
    Gather all releases from git tags, sorted by version.
    Do not include pre releases.
    """
    output = check_output(
        [
            *("git", "tag", "-l"),
            "--format=%(creatordate:iso-strict)|%(refname:short)",
            "--sort=v:refname",  # sort by refname (version sort, not lexicographic)
        ],
        text=True,
    )

    result = []
    for line in output.splitlines():
        date, _, ref = line.partition("|")
        try:
            version = Version(ref)
            if version.pre is not None:
                logger.warning("ignoring pre release: %s", version)
                continue

        except InvalidVersion as exception:
            logger.error("ignoring invalid release: %s", exception)
            continue

        result.append({"id": ref, "date": date})
    return list(reversed(result))


def resolve_query(haystack, needle: str):
    if isinstance(haystack, list):
        needle = int(needle)
    return getitem(haystack, needle)


def main(query: str = None, raw: bool = False) -> int:
    releases = get_releases()
    data = {
        "count": len(releases),
        "latest": releases[0],
        "releases": releases,
    }

    if query is not None:
        parts = query.split(".")
        result = reduce(resolve_query, parts, data)
    else:
        result = data

    if raw:
        print(result)
    else:
        print(json.dumps(result, indent=2))

    return 0


if __name__ == "__main__":
    parser = ArgumentParser("Compile releases data")
    parser.add_argument(
        "-q",
        "--query",
        help="Query a specific data",
    )
    parser.add_argument(
        "-r",
        "--raw",
        action="store_true",
        help="Output raw data",
    )
    args = parser.parse_args()
    raise SystemExit(main(query=args.query, raw=args.raw))
