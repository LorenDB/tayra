#!/bin/bash -eux
# Building sphinx and swagger docs
poetry run sphinx-build . $BUILD_PATH
