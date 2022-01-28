#!/bin/bash -eux

SWAGGER_VERSION="4.1.3"
TARGET_PATH=${TARGET_PATH-"swagger"}
rm -rf $TARGET_PATH /tmp/swagger-ui
git clone --branch="v$SWAGGER_VERSION" --depth=1 "https://github.com/swagger-api/swagger-ui.git" /tmp/swagger-ui
mv /tmp/swagger-ui/dist $TARGET_PATH
cp schema.yml $TARGET_PATH
cp -r api $TARGET_PATH/api
sed -i "s,https://petstore.swagger.io/v2/swagger.json,schema.yml,g" $TARGET_PATH/index.html
