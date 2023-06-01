#!/usr/bin/env bash

set -eux

# given a commit hash, will append this to the version number stored
# in api/funkwhale_api/__init__.py

COMMIT=$1
FILE="api/funkwhale_api/__init__.py"

SUFFIX="\1+git.$COMMIT"
EXPR=$(printf 's@__version__ = "(.*)"@__version__ = "%s"@' "$SUFFIX")
sed -i -E "$EXPR" "$FILE"
