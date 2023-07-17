FROM python:3.11

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ARG PIP_NO_CACHE_DIR=1

RUN set -eux \
    && DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl \
    git \
    graphviz \
    make \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux \
    && pip install --upgrade pip \
    && pip install setuptools wheel pipx \
    && PIPX_BIN_DIR=/usr/local/bin pipx install poetry
