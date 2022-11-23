import sys

import click
from rest_framework.exceptions import ValidationError

from . import library  # noqa
from . import media  # noqa
from . import plugins  # noqa
from . import users  # noqa
from . import base


def invoke():
    try:
        return base.cli()
    except ValidationError as e:
        click.secho("Invalid data:", fg="red")
        for field, errors in e.detail.items():
            click.secho(f"  {field}:", fg="red")
            for error in errors:
                click.secho(f"    - {error}", fg="red")
        sys.exit(1)
