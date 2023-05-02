FROM python:3.11

RUN apt-get update && apt-get install -y graphviz
RUN pip install sphinx livereload sphinx_rtd_theme django-environ django myst-parser sphinx-design sphinx-multiversion sphinxcontrib-mermaid sphinx-copybutton
WORKDIR /app/docs
