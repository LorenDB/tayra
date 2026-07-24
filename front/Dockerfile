# syntax=docker/dockerfile:1.4
#
# Build from the **repository root** (not front/):
#
#   docker compose build front
#
# Requires the Tayra git submodule checked out at ./tayra:
#   git submodule update --init --recursive

ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:stable
ARG FUNKWHALE_URL=

# ── Compile Tayra web ────────────────────────────────────────────────────
FROM ${FLUTTER_IMAGE} AS tayra-builder
ARG FUNKWHALE_URL
WORKDIR /app

# Fail early with a clear message if the submodule is missing/empty.
# (Compose/Docker cannot auto-init git submodules into the build context.)
COPY tayra /tmp/tayra-check
RUN set -eux; \
  if [ ! -f /tmp/tayra-check/pubspec.yaml ]; then \
    echo ""; \
    echo "ERROR: tayra/ submodule is empty or missing pubspec.yaml."; \
    echo "From the repo root run:"; \
    echo "  git submodule update --init --recursive"; \
    echo "Then rebuild: docker compose build front"; \
    echo ""; \
    exit 1; \
  fi; \
  rm -rf /tmp/tayra-check

# Single copy of the whole app (path packages, lib, web/, assets, …)
COPY tayra/ ./

RUN set -eux; \
  flutter config --enable-web; \
  flutter pub get; \
  if [ -n "${FUNKWHALE_URL}" ]; then \
    flutter build web --release --dart-define=FUNKWHALE_URL="${FUNKWHALE_URL}"; \
  else \
    echo "WARNING: FUNKWHALE_URL empty — web login will ask for a server URL"; \
    flutter build web --release; \
  fi

# ── nginx reverse proxy + SPA ────────────────────────────────────────────
FROM nginx:1.23.4-alpine AS production

COPY --from=tayra-builder /app/build/web/ /usr/share/nginx/html/
COPY front/docker/funkwhale.conf.template /etc/nginx/templates/default.conf.template
COPY front/docker/funkwhale_proxy.conf /etc/nginx/funkwhale_proxy.conf
COPY front/docker/entrypoint.sh /docker-entrypoint.d/99-funkwhale.sh
RUN chmod +x /docker-entrypoint.d/99-funkwhale.sh

RUN mkdir -p /var/log/nginx /var/cache/nginx /var/run/nginx && \
    chown -R nginx:nginx /var/log/nginx /var/run/nginx /var/cache/nginx /etc/nginx && \
    sed -e 's#/var/run/nginx.pid#/var/run/nginx/nginx.pid#' -i /etc/nginx/nginx.conf

ENV FUNKWHALE_API_HOST=api
ENV FUNKWHALE_API_PORT=5000
ENV NGINX_MAX_BODY_SIZE=100M

EXPOSE 80
