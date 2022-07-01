#!/bin/sh
poetry run make -e BUILDDIR=locales gettext
for f in $(ls locales | grep -v gettext); do
	poetry run sphinx-intl update -p locales/gettext -l $f
done;
