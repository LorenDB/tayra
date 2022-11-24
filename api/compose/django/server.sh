#!/bin/sh

set -eux

python3 /app/manage.py collectstatic --noinput
python3 /app/manage.py migrate

# shellcheck disable=SC2086
gunicorn config.asgi:application \
    --workers "${FUNKWHALE_WEB_WORKERS-1}" \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:5000 \
    ${GUNICORN_ARGS-}
