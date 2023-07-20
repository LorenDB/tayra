FROM alpine:3.17 as pre-build

# We need this additional step to avoid having poetrys deps interacting with our
# dependencies. This is only required until alpine 3.16 is released, since this
# allows us to install poetry as package.

RUN apk add --no-cache python3 py3-cryptography py3-pip poetry
COPY pyproject.toml poetry.lock /
RUN poetry export --without-hashes > requirements.txt
RUN poetry export --with dev --without-hashes > dev-requirements.txt


FROM alpine:3.17 as builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ARG PIP_NO_CACHE_DIR=1

RUN set -eux; \
  apk add --no-cache \
  cargo \
  curl \
  gcc \
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

# create virtual env for next stage
RUN python3 -m venv --system-site-packages /venv
# emulate activation by prefixing PATH
ENV PATH="/venv/bin:/root/.local/bin:$PATH" VIRTUAL_ENV=/venv

COPY --from=pre-build /requirements.txt /requirements.txt
COPY --from=pre-build /dev-requirements.txt /dev-requirements.txt

RUN set -eux; \
  pip3 install --upgrade pip; \
  pip3 install setuptools wheel; \
  # Currently we are unable to relieably build rust-based packages on armv7. This
  # is why we need to use the packages shipped by Alpine Linux.
  # Since poetry does not allow in-place dependency pinning, we need
  # to install the deps using pip.
  grep -Ev 'cryptography|lxml|pillow|psycopg2|watchfiles' /requirements.txt \
  | pip3 install -r /dev/stdin \
  cryptography==38.0.3 \
  lxml==4.9.3 \
  pillow==9.3.0 \
  psycopg2==2.9.5 \
  watchfiles==0.18.1

ARG install_dev_deps=0
RUN set -eux; \
  if [ "$install_dev_deps" = "1" ] ; then \
    grep -Ev 'cryptography|lxml|pillow|psycopg2|watchfiles' /dev-requirements.txt \
    | pip3 install -r /dev/stdin \
    cryptography==38.0.3 \
    lxml==4.9.3 \
    pillow==9.3.0 \
    psycopg2==2.9.5 \
    watchfiles==0.18.1; \
  fi

FROM alpine:3.17 as image

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
  python3

COPY --from=builder /venv /venv
# emulate activation by prefixing PATH
ENV PATH="/venv/bin:$PATH"

COPY . /app
WORKDIR /app

RUN set -eux; \
  pip3 install --no-deps --editable .

ENV IS_DOCKER_SETUP=true

CMD ["./docker/server.sh"]
