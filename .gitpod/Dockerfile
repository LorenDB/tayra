FROM gitpod/workspace-full:2023-10-25-20-43-33
USER gitpod

RUN sudo apt update -y \
    && sudo apt install libsasl2-dev libldap2-dev libssl-dev ffmpeg gettext -y

RUN pyenv install 3.11 && pyenv global 3.11

RUN pip install poetry pre-commit jinja2 towncrier \
    && poetry config virtualenvs.create true \
    && poetry config virtualenvs.in-project true
