FROM alpine:3.13 as builder

RUN \
    echo 'installing dependencies' && \
    apk add --no-cache \
    git \
    musl-dev \
    gcc \
    postgresql-dev \
    python3-dev \
    py3-psycopg2 \
    py3-cryptography \
    libldap \
    libffi-dev \
    make \
    zlib-dev \
    jpeg-dev \
    openldap-dev \
    openssl-dev \
    cargo \
    libxml2-dev \
    libxslt-dev \
    && \
    ln -s /usr/bin/python3 /usr/bin/python

# create virtual env for next stage
RUN python -m venv --system-site-packages /venv
# emulate activation by prefixing PATH
ENV PATH="/venv/bin:$PATH" VIRTUAL_ENV=/venv

COPY pyproject.toml poetry.lock /
# hack around https://github.com/pypa/pip/issues/6158#issuecomment-456619072
ENV PIP_DOWNLOAD_CACHE=/noop/
RUN \
    echo 'installing pip requirements' && \
    pip3 install --upgrade pip poetry && \
    pip3 install setuptools wheel && \
    poetry export --without-hashes | grep -v cryptography | pip3 install -r /dev/stdin cryptography==3.3.2 && \
    rm -rf $PIP_DOWNLOAD_CACHE

ARG install_dev_deps=0
RUN \
    if [ "$install_dev_deps" = "1" ] ; then \
      echo "Installing dev dependencies" && \
    poetry export --dev --without-hashes | grep -v cryptography | pip3 install -r /dev/stdin cryptography==3.3.2 && \
    ; else  \
      echo "Skipping dev deps installation" \
    ; fi


FROM alpine:3.13 as build-image

COPY --from=builder /venv /venv
# emulate activation by prefixing PATH
ENV PATH="/venv/bin:$PATH"

RUN apk add --no-cache \
    libmagic \
    bash \
    gettext \
    python3 \
    jpeg-dev \
    ffmpeg \
    libpq \
    libxml2 \
    libxslt \
    py3-cryptography \
    && \
    ln -s /usr/bin/python3 /usr/bin/python

COPY . /app
WORKDIR /app

RUN find . -type d -exec chmod 755 {} \+

ENTRYPOINT ["./compose/django/entrypoint.sh"]
CMD ["./compose/django/server.sh"]
