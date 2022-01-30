FROM alpine:3.15 as builder

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
    curl \
    && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    curl -sSL https://install.python-poetry.org | python3 -

# create virtual env for next stage
RUN python -m venv --system-site-packages /venv
# emulate activation by prefixing PATH
ENV PATH="/venv/bin:/root/.local/bin:$PATH" VIRTUAL_ENV=/venv

COPY pyproject.toml poetry.lock /
# hack around https://github.com/pypa/pip/issues/6158#issuecomment-456619072
ENV PIP_DOWNLOAD_CACHE=/noop/
RUN \
    echo 'installing pip requirements' && \
    pip3 install --upgrade pip && \
    pip3 install setuptools wheel && \
    # Currently we are unable to relieably build cryptography on armv7. This
    # is why we need to use the package shipped by Alpine Linux, which is currently
    # version 3.3.2. Since poetry does not allow in-place dependency pinning, we need
    # to install the deps using pip.
    poetry export --without-hashes | grep -Ev 'cryptography|autobahn' | pip3 install -r /dev/stdin cryptography==3.3.2 autobahn==21.3.1 && \
    rm -rf $PIP_DOWNLOAD_CACHE

ARG install_dev_deps=0
RUN \
    if [ "$install_dev_deps" = "1" ] ; then \
      echo "Installing dev dependencies" && \
    poetry export --dev --without-hashes | grep -Ev 'cryptography|autobahn' | pip3 install -r /dev/stdin cryptography==3.3.2 autobahn==21.3.1 \
    ; else  \
      echo "Skipping dev deps installation" \
    ; fi


FROM alpine:3.15 as build-image

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
