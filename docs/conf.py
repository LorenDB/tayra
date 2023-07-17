# All configuration values have a default; values that are commented out
# serve to show the default.
#
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import os
from datetime import datetime
from pathlib import Path

from sphinx.application import Sphinx
from sphinx.util import logging

import funkwhale_api

logger = logging.getLogger(__name__)


FUNKWHALE_CONFIG = {
    "FUNKWHALE_URL": "https://pod.funkwhale",
    "DATABASE_URL": "postgres://localhost:5432/funkwhale",
    "AWS_ACCESS_KEY_ID": "my_access_key",
    "AWS_SECRET_ACCESS_KEY": "my_secret_key",
    "AWS_STORAGE_BUCKET_NAME": "my_bucket",
}
os.environ.update(**FUNKWHALE_CONFIG)

# -- General configuration ------------------------------------------------

# General information about the project.
year = datetime.now().year
project = "funkwhale"
copyright = f"{year}, The Funkwhale Collective"
author = "The Funkwhale Collective"
version = funkwhale_api.__version__
release = version

extensions = [
    "sphinx_copybutton",
    "sphinx_design",
    "sphinx.ext.autodoc",
    "sphinx.ext.graphviz",
    "sphinxcontrib.mermaid",
    "myst_parser",
]

source_suffix = ".md"
include_patterns = [
    "_static/**",
    "_templates/**",
    "*_documentation/**",
    "*.md",
    "*.rst",
    "logo.svg",
]
exclude_patterns = [
    "_build",
    "_scripts",
    ".venv",
    ".DS_Store",
    "Thumbs.db",
    "*.py",
    "*.sh",
]

root_doc = "index"

# autodoc
autodoc_mock_imports = [
    "celery",
    "django_auth_ldap",
    "ldap",
    "persisting_theory",
    "rest_framework",
    "drf_spectacular",
]

# sphinx
pygments_style = "sphinx"
add_module_names = False
todo_include_todos = False

# myst
myst_enable_extensions = [
    "colon_fence",
    "attrs_block",
    "tasklist",
    "fieldlist",
    "deflist",
]
myst_heading_anchors = 3


# internationalization
locale_dirs = ["locales/"]
gettext_compact = False
language = "en"

# copybutton
copybutton_exclude = ".linenos, .gp"


# -- Options for HTML output ----------------------------------------------

html_theme = "sphinx_rtd_theme"
html_context = {
    "display_gitlab": True,
    "gitlab_host": "dev.funkwhale.audio",
    "gitlab_repo": "funkwhale",
    "gitlab_user": "funkwhale",
    "gitlab_version": "stable",
    "conf_py_path": "/docs/",
    "gitlab_url": "https://dev.funkwhale.audio/funkwhale/funkwhale",
}
html_logo = "logo.svg"
html_favicon = "../front/public/favicon.ico"
html_static_path = ["_static"]
html_css_files = ["css/translation-hint.css"]
html_js_files = ["js/translation-hint.js"]

# -- Options for HTMLHelp output ------------------------------------------

htmlhelp_basename = "funkwhaledoc"

# -- Options for LaTeX output ---------------------------------------------

latex_documents = [
    (
        root_doc,
        "funkwhale.tex",
        "Funkwhale Documentation",
        "The Funkwhale Collective",
        "manual",
    )
]

# -- Options for manual page output ---------------------------------------

man_pages = [
    (
        root_doc,
        "funkwhale",
        "Funkwhale Documentation",
        [author],
        1,
    )
]

# -- Options for Texinfo output -------------------------------------------

# Grouping the document tree into Texinfo files. List of tuples
# (source start file, target name, title, author,
#  dir menu entry, description, category)
texinfo_documents = [
    (
        root_doc,
        "funkwhale",
        "Funkwhale Documentation",
        author,
        "funkwhale",
        "One line description of project.",
        "Miscellaneous",
    )
]

# -- Setup legacy redirects -----------------------------------------------

REDIRECT_TEMPLATE = """\
<html>
  <head>
    <meta http-equiv="refresh" content="1; url={url}" />
    <script>
      window.location.href = "{url}"
    </script>
  </head>
</html>
"""

redirects_file = Path("redirects.txt")
redirects = [
    tuple(line.strip().split(", "))
    for line in redirects_file.read_text(encoding="utf-8").splitlines()
]


def copy_legacy_redirects(app: Sphinx, docname):
    if app.builder.name == "html":
        for src_path, dest_url in redirects:
            content = REDIRECT_TEMPLATE.format(url=dest_url)

            redirect_path = Path(app.outdir) / src_path
            redirect_path.parent.mkdir(parents=True, exist_ok=True)
            redirect_path.write_text(content, encoding="utf-8")


def setup(app):
    app.connect("build-finished", copy_legacy_redirects)
