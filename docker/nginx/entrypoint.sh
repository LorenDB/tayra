#!/bin/sh

set -eux

TEMPLATE_PATH="/etc/nginx/nginx.conf.template"
CONFIG_PATH="/etc/nginx/nginx.conf"

ALLOWED_VARS="$(env | cut -d '=' -f 1 | xargs printf "\${%s} ")"
envsubst "$ALLOWED_VARS" < "$TEMPLATE_PATH" | tee "$CONFIG_PATH"

nginx-debug -g 'daemon off;'
