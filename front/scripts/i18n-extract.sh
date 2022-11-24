#!/usr/bin/env bash

set -eux

cd "$(dirname "$0")/.." # change into base directory
# shellcheck disable=SC1091
source scripts/utils.sh

locales=$(jq -r '.[].code' src/locales.json)
locales_dir="locales"
sources=$(find src -name '*.vue' -o -name '*.html' 2> /dev/null)
js_sources=$(find src -name '*.vue' -o -name '*.js')
touch "$locales_dir/app.pot"
GENERATE="${GENERATE-true}"

# Create a main .pot template, then generate .po files for each available language.
# Extract gettext strings from templates files and create a POT dictionary template.
# shellcheck disable=SC2086
"$(npm_binaries)/gettext-extract" --attribute v-translate --quiet --output "$locales_dir/app.pot" $sources

# shellcheck disable=SC2086
xgettext --language=JavaScript --keyword=npgettext:1c,2,3 \
  --from-code=utf-8 --join-existing --no-wrap \
  --package-name="$(jq -r '.name' package.json)" \
  --package-version="$(jq -r '.version' package.json)" \
  --output "$locales_dir/app.pot" $js_sources \
  --no-wrap

# Fix broken files path/lines in pot
sed -e 's|#: src/|#: front/src/|' -i "$locales_dir/app.pot"

if [ "$GENERATE" = 'true' ]; then
  # Generate .po files for each available language.
  echo "$locales"
  for lang in $locales; do
    po_file="$locales_dir/$lang/LC_MESSAGES/app.po"
    echo "msgmerge --update $po_file"
    mkdir -p "$(dirname "$po_file")"

    if [[ -f "$po_file" ]]; then
      msgmerge --lang="$lang" --update "$po_file" "$locales_dir/app.pot" --no-wrap
    else
      msginit --no-wrap --no-translator --locale="$lang" --input="$locales_dir/app.pot" --output-file="$po_file"
    fi

    msgattrib --no-wrap --no-obsolete -o "$po_file" "$po_file"
  done
fi
