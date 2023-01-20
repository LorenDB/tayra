def test_version():
    from funkwhale_api import __version__, version

    assert isinstance(version, str)
    assert version == __version__
