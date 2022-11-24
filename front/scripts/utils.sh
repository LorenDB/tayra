#!/usr/bin/env bash

set -eux

npm_binaries()  {
  if command -v yarn > /dev/null; then
    yarn bin
  else
    npm bin
  fi
}
