#!/bin/bash -eux
# Building sphinx and swagger docs
poetry run sphinx-multiversion . $BUILD_PATH
TARGET_PATH="$BUILD_PATH/swagger" ./build_swagger.sh
python ./get-releases-json.py > $BUILD_PATH/releases.json
python ./get-releases-json.py --latest > $BUILD_PATH/latest.txt
