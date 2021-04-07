#!/usr/bin/env bash -S -eux

npm_binaries () {
  command -v yarn > /dev/null && yarn bin || npm bin
}
