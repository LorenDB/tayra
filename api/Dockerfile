FROM alpine:3.17 as requirements

# Isolate poetry from runtime deps. Export only — pip installs the real
# packages in the builder stage.
#
# poetry.lock is generated with Poetry 2.x (lock-version 2.1). Alpine 3.17
# only ships Poetry 1.2.2, which cannot read that lock format. Install a
# matching Poetry into its own venv (system pip conflicts with apk distutils
# packages). poetry export lives in poetry-plugin-export as of Poetry 2.0.

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

FROM alpine:3.17 as builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ARG PIP_NO_CACHE_DIR=1
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

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
  py3-cryptography=38.0.3-r1 \
  py3-lxml=4.9.3-r1 \
  py3-pillow=9.3.0-r0 \
  py3-psycopg2=2.9.5-r0 \
  py3-watchfiles=0.18.1-r0 \
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
  # Currently we are unable to relieably build rust-based packages on armv7. This
  # is why we need to use the packages shipped by Alpine Linux.
  # Since poetry does not allow in-place dependency pinning, we need
  # to install the deps using pip.
  grep -Ev 'cryptography|lxml|pillow|psycopg2|watchfiles' /requirements.txt \
  | pip3 install --no-build-isolation -r /dev/stdin \
  cryptography==38.0.3 \
  lxml==4.9.3 \
  pillow==9.3.0 \
  psycopg2==2.9.5 \
  watchfiles==0.18.1

ARG install_dev_deps=0
RUN --mount=type=cache,target=~/.cache/pip; \
  set -eux; \
  if [ "$install_dev_deps" = "1" ] ; then \
    grep -Ev 'cryptography|lxml|pillow|psycopg2|watchfiles' /dev-requirements.txt \
    | pip3 install --no-build-isolation -r /dev/stdin \
    cryptography==38.0.3 \
    lxml==4.9.3 \
    pillow==9.3.0 \
    psycopg2==2.9.5 \
    watchfiles==0.18.1; \
  fi

FROM alpine:3.17 as production

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ARG PIP_NO_CACHE_DIR=1

RUN set -eux; \
  apk add --no-cache \
  bash \
  ffmpeg \
  gettext \
  jpeg-dev \
  libldap \
  libmagic \
  libpq \
  libxml2 \
  libxslt \
  py3-cryptography=38.0.3-r1 \
  py3-lxml=4.9.3-r1 \
  py3-pillow=9.3.0-r0 \
  py3-psycopg2=2.9.5-r0 \
  py3-watchfiles=0.18.1-r0 \
  python3 \
  tzdata

COPY --from=builder /venv /venv
ENV PATH="/venv/bin:$PATH"

COPY . /app
WORKDIR /app

# Fail the build if a .dockerignore (or incomplete checkout) dropped the
# Typesense Django app — INSTALLED_APPS expects it unless we soft-disable.
RUN test -f funkwhale_api/typesense/__init__.py

RUN --mount=type=cache,target=~/.cache/pip; \
  set -eux; \
  pip3 install --no-deps --editable .

ENV IS_DOCKER_SETUP=true

CMD ["./docker/server.sh"]
