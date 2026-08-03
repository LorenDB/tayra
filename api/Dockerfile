# M11: supported Alpine (3.19 ships Python 3.11, within pyproject ^3.8,<3.12).
FROM alpine:3.19 as requirements

# Isolate poetry from runtime deps. Export only — pip installs the real
# packages in the builder stage.
#
# poetry.lock is generated with Poetry 2.x (lock-version 2.1). Install a
# matching Poetry into its own venv. poetry export lives in poetry-plugin-export
# as of Poetry 2.0.

RUN set -eux; \
  apk add --no-cache \
  py3-pip \
  python3; \
  python3 -m venv /opt/poetry; \
  /opt/poetry/bin/pip install --no-cache-dir "poetry==2.2.1" "poetry-plugin-export"; \
  ln -s /opt/poetry/bin/poetry /usr/local/bin/poetry

COPY pyproject.toml poetry.lock /
RUN set -eux; \
  poetry export --without-hashes --extras typesense > requirements.txt; \
  poetry export --without-hashes --with dev > dev-requirements.txt;

FROM alpine:3.19 as builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ARG PIP_NO_CACHE_DIR=1
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

# M1/M11: install build deps; security-sensitive pure/wheels come from pip
# (cryptography, pillow, aiohttp) rather than EOL Alpine package pins.
RUN set -eux; \
  apk add --no-cache \
  cargo \
  curl \
  gcc \
  g++ \
  git \
  jpeg-dev \
  libffi-dev \
  libldap \
  libxml2-dev \
  libxslt-dev \
  make \
  musl-dev \
  openldap-dev \
  openssl-dev \
  postgresql-dev \
  zlib-dev \
  py3-lxml \
  py3-psycopg2 \
  python3-dev

# Create virtual env
RUN python3 -m venv --system-site-packages /venv
ENV PATH="/venv/bin:$PATH"

COPY --from=requirements /requirements.txt /requirements.txt
COPY --from=requirements /dev-requirements.txt /dev-requirements.txt

# Pin setuptools: modern setuptools dropped convert_path, which breaks
# building django-allauth==0.42.0 (and other 2020-era sdists) from source.
# --no-build-isolation makes pip use this setuptools instead of an isolated
# latest copy. Matches api/pyproject.toml setuptools==60.10.0 (1.4.0 pin).
RUN --mount=type=cache,target=~/.cache/pip; \
  set -eux; \
  pip3 install --upgrade "pip==24.0"; \
  pip3 install "setuptools==60.10.0" "wheel==0.42.0"; \
  # lxml/psycopg2 still prefer Alpine system packages on armv7; everything
  # else (including cryptography, pillow) installs from requirements.
  grep -Ev 'lxml|psycopg2' /requirements.txt \
  | pip3 install --no-build-isolation -r /dev/stdin \
  lxml \
  psycopg2

ARG install_dev_deps=0
RUN --mount=type=cache,target=~/.cache/pip; \
  set -eux; \
  if [ "$install_dev_deps" = "1" ] ; then \
    grep -Ev 'lxml|psycopg2' /dev-requirements.txt \
    | pip3 install --no-build-isolation -r /dev/stdin \
    lxml \
    psycopg2; \
  fi

FROM alpine:3.19 as production

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ARG PIP_NO_CACHE_DIR=1

RUN set -eux; \
  apk add --no-cache \
  bash \
  ffmpeg \
  gettext \
  jpeg \
  libffi \
  libldap \
  libmagic \
  libpq \
  libxml2 \
  libxslt \
  py3-lxml \
  py3-psycopg2 \
  python3 \
  # su-exec: root entrypoint drops to funkwhale after fixing volume ownership
  su-exec \
  tzdata; \
  # M5: run API/celery as non-root (entrypoint drops privileges)
  addgroup -g 1000 -S funkwhale; \
  adduser -u 1000 -S -G funkwhale -h /app -s /sbin/nologin funkwhale; \
  mkdir -p /srv/funkwhale/data/media /srv/funkwhale/data/static /music; \
  chown -R funkwhale:funkwhale /srv/funkwhale

COPY --from=builder /venv /venv
ENV PATH="/venv/bin:$PATH"

COPY --chown=funkwhale:funkwhale . /app
WORKDIR /app

# Fail the build if a .dockerignore (or incomplete checkout) dropped the
# Typesense Django app — INSTALLED_APPS expects it unless we soft-disable.
RUN test -f funkwhale_api/typesense/__init__.py

# Do not chown /venv here: it is ~30k files and recursive chown hangs for
# minutes on Docker Desktop (virtiofs) with no BuildKit progress. A
# root-owned venv is fine for USER funkwhale — site-packages only need
# read/execute. pip -e writes egg-info under /app, so chown that only.
RUN set -eux; \
  pip3 install --no-deps --editable .; \
  chown -R funkwhale:funkwhale /app; \
  chmod +x /app/docker/entrypoint.sh /app/docker/server.sh

# Stay root for entrypoint so bind-mounted data/static + data/media can be
# chown'd when host ownership is wrong; entrypoint then su-exec's to funkwhale.
ENV IS_DOCKER_SETUP=true

ENTRYPOINT ["./docker/entrypoint.sh"]
CMD ["./docker/server.sh"]
