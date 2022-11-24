#!/usr/bin/env bash

set -eux

cd "$(dirname "$0")/.." # change into base directory

FOMANTIC_SRC_PATH="node_modules/fomantic-ui-css"

find "$FOMANTIC_SRC_PATH/components" -name "*.min.css" -delete
mkdir -p "$FOMANTIC_SRC_PATH/tweaked"

echo 'Removing google font…'
sed -i '/@import url(/d' "$FOMANTIC_SRC_PATH/components/site.css"

echo "Replacing hardcoded values by CSS vars…"
scripts/fix-fomantic-css.py "$FOMANTIC_SRC_PATH" "$FOMANTIC_SRC_PATH/tweaked"

echo 'Fixing jQuery import…'
# shellcheck disable=SC2046
sed -i '1s/^/import jQuery from "jquery"\n/' $(find "$FOMANTIC_SRC_PATH" -name '*.js')
