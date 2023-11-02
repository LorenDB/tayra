FROM gitpod/workspace-full:2022-11-15-17-00-18
USER gitpod

RUN sudo apt update -y \
    && sudo apt install libsasl2-dev libldap2-dev libssl-dev ffmpeg gettext -y

RUN pip install poetry pre-commit \
    && poetry config virtualenvs.create true \
    && poetry config virtualenvs.in-project true
