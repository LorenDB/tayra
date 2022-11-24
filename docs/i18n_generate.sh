#!/usr/bin/env bash

poetry run make -e BUILDDIR=locales gettext

for path in locales/*; do
  lang="$(basename "$path")"
  if [[ "$lang" != "gettext" ]]; then
    poetry run sphinx-intl update -p locales/gettext -l "$lang"
  fi
done
