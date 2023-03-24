#!/bin/sh

set -eux

funkwhale-manage collectstatic --noinput
funkwhale-manage migrate

# shellcheck disable=SC2086
exec gunicorn config.asgi:application \
    --workers "${FUNKWHALE_WEB_WORKERS-1}" \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:5000 \
    ${GUNICORN_ARGS-}
