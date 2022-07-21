FROM gitpod/workspace-full:2022-07-12-11-05-29
USER gitpod

RUN sudo apt update -y \
    && sudo apt install libsasl2-dev libldap2-dev libssl-dev ffmpeg gettext -y

RUN pip install poetry \
    && poetry config virtualenvs.create true \
    && poetry config virtualenvs.in-project true 