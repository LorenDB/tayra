#!/usr/bin/env bash

set -eux

cd "$(dirname "$0")/.." # change into base directory

npm_binaries()  {
  if command -v yarn > /dev/null; then
    yarn bin
  else
    npm bin
  fi
}

locales=$(jq -r '.[].code' src/locales.json | grep -v 'en_US')
mkdir -p src/translations

for locale in $locales; do
  "$(npm_binaries)/gettext-compile" "locales/$locale/LC_MESSAGES/app.po" --output "src/translations/$locale.json"
done

# find locales -name '*.po' | xargs "$(npm_binaries)/.bin/gettext-compile" --output src/translations.json
