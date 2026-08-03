#!/bin/sh
# Drop privileges after fixing bind-mount ownership.
#
# compose must not force user: "1000:1000" — that skips the root branch and
# leaves host-mounted static/media unfixable when they are root-owned
# (common after an older root-run container or a root-created bind mount).

set -eu

STATIC_ROOT="${STATIC_ROOT:-/srv/funkwhale/data/static}"
MEDIA_ROOT="${MEDIA_ROOT:-/srv/funkwhale/data/media}"

if [ "$(id -u)" -eq 0 ]; then
  mkdir -p "$STATIC_ROOT" "$MEDIA_ROOT"

  # Static is rewritten by collectstatic on every boot — always fix ownership.
  chown -R funkwhale:funkwhale "$STATIC_ROOT"

  # Media can be large; only recurse when the runtime user cannot write.
  chown funkwhale:funkwhale "$MEDIA_ROOT" || true
  if ! su-exec funkwhale test -w "$MEDIA_ROOT"; then
    echo "entrypoint: MEDIA_ROOT not writable by funkwhale; fixing ownership (may be slow)"
    chown -R funkwhale:funkwhale "$MEDIA_ROOT"
  fi

  exec su-exec funkwhale:funkwhale "$@"
fi

# Non-root start (e.g. compose user: override): fail with a clear hint.
if [ ! -w "$STATIC_ROOT" ] 2>/dev/null; then
  echo "ERROR: ${STATIC_ROOT} is not writable by uid $(id -u)." >&2
  echo "Bind mounts must be owned by UID/GID 1000, or start the container as root" >&2
  echo "so this entrypoint can chown them. On the host:" >&2
  echo "  mkdir -p data/static data/media && sudo chown -R 1000:1000 data/static data/media" >&2
  exit 1
fi

exec "$@"
