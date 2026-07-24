# syntax=docker/dockerfile:1.4
#
# Build from the **repository root** (not front/):
#
#   docker compose build front
#   # or
#   docker build -f front/Dockerfile \
#     --build-arg FUNKWHALE_URL=https://music.example.com \
#     -t funkwhale-tayra/front:local .
#
# Expects the Tayra git submodule at ./tayra (see .gitmodules).

ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:stable
ARG FUNKWHALE_URL=

# ── Compile Tayra web ────────────────────────────────────────────────────
FROM ${FLUTTER_IMAGE} AS tayra-builder
ARG FUNKWHALE_URL
WORKDIR /app

COPY tayra/pubspec.yaml tayra/pubspec.lock ./
COPY tayra/packages ./packages
# Fetch deps before full copy for better layer caching when only app code changes
RUN flutter config --enable-web && flutter pub get

COPY tayra/ ./
RUN set -eux; \
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
