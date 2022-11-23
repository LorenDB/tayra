#!/usr/bin/env python3
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")

    try:
        import django
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc

    if len(sys.argv) > 1 and sys.argv[1] in ["fw", "funkwhale"]:
        django.setup()

        from funkwhale_api.cli import main as cli

        sys.argv = sys.argv[1:]
        cli.invoke()

    else:
        execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
