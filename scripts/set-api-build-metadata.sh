#!/usr/bin/env bash

# Given a commit hash, this script will update the version in api/pyproject.toml
# The version must follow the pep440 specification https://peps.python.org/pep-0440/

set -eu

error() {
  echo >&2 "error: $*"
  exit 1
}

command -v git > /dev/null || error "git command not found!"
command -v poetry > /dev/null || error "poetry command not found!"

# We assume this script only runs in a git repository
cd "$(git rev-parse --show-toplevel)/api"

COMMIT_SHA="$1"

CURRENT_VERSION="$(poetry version --short)"
CURRENT_VERSION="${CURRENT_VERSION%%.dev*}"

VERSION_SUFFIX="dev+$COMMIT_SHA"

poetry version "$CURRENT_VERSION-$VERSION_SUFFIX"
