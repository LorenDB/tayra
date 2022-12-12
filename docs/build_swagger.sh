#!/usr/bin/env bash
set -eux

SWAGGER_VERSION="4.15.5"
TARGET_PATH=${TARGET_PATH-"swagger"}

rm -rf "$TARGET_PATH"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

pushd "$tmpdir"
wget "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v$SWAGGER_VERSION.tar.gz" -O swagger-ui.tgz
tar -xzf swagger-ui.tgz
popd
mv "$tmpdir/"*/dist "$TARGET_PATH"
cp schema.yml "$TARGET_PATH"

sed -i "s#https://petstore.swagger.io/v2/swagger.json#schema.yml#g" "$TARGET_PATH/swagger-initializer.js"
