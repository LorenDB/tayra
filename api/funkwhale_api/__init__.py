from importlib.metadata import version as get_version

version = get_version("funkwhale_api")
__version__ = version
