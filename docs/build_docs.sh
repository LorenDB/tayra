#!/bin/bash -eux
# Building sphinx and swagger docs
poetry run python -m sphinx . $BUILD_PATH # TODO enable multi version #1739
TARGET_PATH="$BUILD_PATH/swagger" ./build_swagger.sh
python ./get-releases-json.py > $BUILD_PATH/releases.json
python ./get-releases-json.py --latest > $BUILD_PATH/latest.txt
