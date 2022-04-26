#!/bin/bash -eux
# We clean up translations, only fully translated components are kept
IFS=$'\n'

for i in $(poetry run sphinx-intl stat); do
	echo "$i"
	if [[ "$i" != *" 0 untranslated." ]]; then
		file=$(echo $i | cut -d: -f1)
		echo "delete $file"
		rm $file
	fi
done
# Build sphinx
poetry run sphinx-multiversion . $BUILD_PATH
for d in $(ls locales); do
	if [[ $d != "gettext" ]]; then
		poetry run sphinx-multiversion -D language="$d" . $BUILD_PATH/$d
	fi
done

# Build swagger
TARGET_PATH="$BUILD_PATH/swagger" ./build_swagger.sh
python ./get-releases-json.py > $BUILD_PATH/releases.json
python ./get-releases-json.py --latest > $BUILD_PATH/latest.txt
