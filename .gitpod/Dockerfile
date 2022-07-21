FROM gitpod/workspace-full:2022-07-17-14-41-27
USER gitpod

RUN sudo apt update -y \
    && sudo apt install libsasl2-dev libldap2-dev libssl-dev ffmpeg gettext -y

RUN pip install poetry \
    && poetry config virtualenvs.create true \
    && poetry config virtualenvs.in-project true 