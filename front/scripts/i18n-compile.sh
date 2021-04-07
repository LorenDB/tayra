#!/usr/bin/env -S bash -eux

cd "$(dirname $0)/.." # change into base directory
source scripts/utils.sh

locales=$(tail -n +2 src/locales.js | sed -e 's/export default //' | jq '.locales[].code' | grep -v 'en_US' | xargs echo)
mkdir -p src/translations

for locale in $locales; do
  $(npm_binaries)/gettext-compile locales/$locale/LC_MESSAGES/app.po --output src/translations/$locale.json
done

# find locales -name '*.po' | xargs $(npm_binaries)/.bin/gettext-compile --output src/translations.json
