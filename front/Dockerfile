# syntax=docker/dockerfile:1.4
#
# Build from the **repository root** (not front/):
#
#   docker compose build front
#
# Compiles the Flutter client that lives at the repository root
# (pubspec.yaml, lib/, web/, assets/, packages/, …).

# M11: pin a concrete Flutter image tag (override at build time if needed).
# "stable" floats; pin reduces supply-chain surprise. Bump deliberately.
ARG FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:3.32.0
ARG FUNKWHALE_URL=

# ── Compile Tayra web ────────────────────────────────────────────────────
FROM ${FLUTTER_IMAGE} AS tayra-builder
ARG FUNKWHALE_URL
WORKDIR /app

# Fail early if Flutter sources are missing from the build context.
COPY pubspec.yaml /tmp/tayra-check/pubspec.yaml
RUN set -eux; \
  if [ ! -f /tmp/tayra-check/pubspec.yaml ]; then \
    echo ""; \
    echo "ERROR: pubspec.yaml missing from build context."; \
    echo "Build front from the repository root:"; \
    echo "  docker compose build front"; \
    echo ""; \
    exit 1; \
  fi; \
  rm -rf /tmp/tayra-check

# Flutter app sources at monorepo root (exclude heavy/server trees via .dockerignore)
COPY pubspec.yaml pubspec.lock ./
COPY analysis_options.yaml ./
COPY lib ./lib
COPY web ./web
COPY assets ./assets
COPY packages ./packages
# Optional platform folders some path packages may reference
COPY android ./android
COPY linux ./linux
COPY macos ./macos
COPY windows ./windows

# --no-web-resources-cdn: ship CanvasKit/wasm from this origin so the
# Funkwhale CSP (script-src 'self') does not block gstatic.com.
RUN set -eux; \
  flutter config --enable-web; \
  flutter pub get; \
  if [ -n "${FUNKWHALE_URL}" ]; then \
    flutter build web --release --no-web-resources-cdn \
      --dart-define=FUNKWHALE_URL="${FUNKWHALE_URL}"; \
  else \
    echo "WARNING: FUNKWHALE_URL empty — web login will ask for a server URL"; \
    flutter build web --release --no-web-resources-cdn; \
  fi

# ── nginx reverse proxy + SPA ────────────────────────────────────────────
# M11: supported nginx alpine (1.23 is EOL).
FROM nginx:1.27-alpine AS production

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
