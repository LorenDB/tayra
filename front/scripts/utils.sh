#!/usr/bin/env -S bash -eux

npm_binaries () {
  command -v yarn > /dev/null && yarn bin || npm bin
}
