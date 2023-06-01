#!/bin/sh

if [ -n "$AWS_S3_ENDPOINT_URL" ]; then
  # uncomment S3 section in media location and comment NON-S3 section
  sed -i '/# NON-S3/s/^/#/g;/# S3/s/^#//g' /etc/nginx/conf.d/default.conf
fi

cat /etc/nginx/conf.d/default.conf
