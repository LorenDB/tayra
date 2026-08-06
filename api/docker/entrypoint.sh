#!/bin/sh
# Drop privileges after fixing bind-mount ownership.
#
# compose must not force user: "1000:1000" — that skips the root branch and
# leaves host-mounted static/media unusable when they are root-owned
# (common after an older root-run container or a root-created bind mount).

set -eu

STATIC_ROOT="${STATIC_ROOT:-/srv/funkwhale/data/static}"
MEDIA_ROOT="${MEDIA_ROOT:-/srv/funkwhale/data/media}"

# nginx (front) serves audio via X-Accel-Redirect as the unprivileged
# ``nginx`` user. Media must be world-readable/traversable or nginx returns
# 403 Permission denied *after* the API has already authorized the request
# (share tokens, OAuth, etc.). Paths are only reachable via internal
# ``/_protected/media/`` — not listed as a public directory index.
_fix_media_readable_for_proxy() {
  chmod a+rx "$MEDIA_ROOT" 2>/dev/null || true
  for d in tracks transcoded attachments __sized__; do
    if [ -d "$MEDIA_ROOT/$d" ]; then
      find "$MEDIA_ROOT/$d" -type d -exec chmod a+rx {} + 2>/dev/null || true
      find "$MEDIA_ROOT/$d" -type f -exec chmod a+r {} + 2>/dev/null || true
    fi
  done
}

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
  # Nested root-owned trees (docker exec as root, one-off tools) leave nginx
  # unable to open files even when the top-level media dir is fine.
  if find "$MEDIA_ROOT" -user root -print -quit 2>/dev/null | grep -q .; then
    echo "entrypoint: fixing root-owned paths under MEDIA_ROOT (may be slow)"
    chown -R funkwhale:funkwhale "$MEDIA_ROOT"
  fi

  _fix_media_readable_for_proxy

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
