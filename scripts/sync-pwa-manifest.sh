#!/usr/bin/env bash

set -eu

SRC="front/pwa-manifest.json"
DEST="api/funkwhale_api/instance/pwa-manifest.json"

cp "$SRC" "$DEST"
