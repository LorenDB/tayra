#!/usr/bin/env bash

set -eux

# We clean up translations, only fully translated components are kept
IFS=$'\n'

for i in $(poetry run sphinx-intl stat); do
  echo "$i"
  if [[ "$i" != *" 0 untranslated." ]]; then
    file=$(echo "$i" | cut -d: -f1)
    echo "delete $file"
    rm "$file"
  fi
done

# Build sphinx
poetry run sphinx-build . "$BUILD_PATH"
for path in locales/*; do
  lang="$(basename "$path")"
  if [[ "$lang" != "gettext" ]]; then
    poetry run sphinx-build -D language="$lang" . "$BUILD_PATH/$lang"
  fi
done

# Build swagger
TARGET_PATH="$BUILD_PATH/swagger" ./build_swagger.sh
python3 ./get-releases-json.py > "$BUILD_PATH/releases.json"
python3 ./get-releases-json.py --latest > "$BUILD_PATH/latest.txt"
