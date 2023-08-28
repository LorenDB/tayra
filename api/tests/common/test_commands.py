import os
from io import StringIO

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from funkwhale_api.federation import models as federation_models
from funkwhale_api.music import models as music_models
from funkwhale_api.tags import models as tags_models
from funkwhale_api.users import models as users_models


def test_load_test_data_dry_run(factories, mocker):
    call_command("load_test_data", artists=10)

    assert music_models.Artist.objects.count() == 0


@pytest.mark.parametrize(
    "kwargs, expected_counts",
    [
        (
            {"create_dependencies": True, "artists": 10},
            [(music_models.Artist.objects.all(), 10)],
        ),
        (
            {"create_dependencies": True, "albums": 10, "artists": 1},
            [
                (music_models.Album.objects.all(), 10),
                (music_models.Artist.objects.all(), 1),
            ],
        ),
        (
            {"create_dependencies": True, "tracks": 20, "albums": 10, "artists": 1},
            [
                (music_models.Track.objects.all(), 20),
                (music_models.Album.objects.all(), 10),
                (music_models.Artist.objects.all(), 1),
            ],
        ),
        (
            {"create_dependencies": True, "albums": 10, "albums_artist_factor": 0.5},
            [
                (music_models.Album.objects.all(), 10),
                (music_models.Artist.objects.all(), 5),
            ],
        ),
        (
            {"create_dependencies": True, "albums": 3},
            [
                (music_models.Album.objects.all(), 3),
                (music_models.Artist.objects.all(), 1),
            ],
        ),
        (
            {"create_dependencies": True, "local_accounts": 3},
            [
                (users_models.User.objects.all(), 3),
                (federation_models.Actor.objects.all(), 3),
            ],
        ),
        (
            {"create_dependencies": True, "local_libraries": 3},
            [
                (users_models.User.objects.all(), 3),
                (federation_models.Actor.objects.all(), 3),
                (music_models.Library.objects.all(), 3),
            ],
        ),
        (
            {"create_dependencies": True, "local_uploads": 3},
            [
                (users_models.User.objects.all(), 1),
                (federation_models.Actor.objects.all(), 1),
                (music_models.Library.objects.all(), 1),
                (music_models.Upload.objects.filter(import_status="finished"), 3),
                (music_models.Track.objects.all(), 3),
            ],
        ),
        (
            {"create_dependencies": True, "tags": 3},
            [(tags_models.Tag.objects.all(), 3)],
        ),
        (
            {"create_dependencies": True, "track_tags": 3},
            [(tags_models.Tag.objects.all(), 1), (music_models.Track.objects.all(), 3)],
        ),
    ],
)
def test_load_test_data_args(factories, kwargs, expected_counts, mocker):
    call_command("load_test_data", dry_run=False, **kwargs)

    for qs, expected_count in expected_counts:
        assert qs.count() == expected_count


def test_load_test_data_skip_dependencies(factories):
    factories["music.Artist"].create_batch(size=5)
    call_command("load_test_data", dry_run=False, albums=10, create_dependencies=False)

    assert music_models.Artist.objects.count() == 5
    assert music_models.Album.objects.count() == 10


commands = ["createsuperuser", "makemigrations"]


@pytest.mark.parametrize("command", commands)
def test_blocked_commands(command):
    with pytest.raises(CommandError):
        call_command(command)


@pytest.mark.parametrize("command", commands)
def test_unblocked_commands(command, mocker):
    mocker.patch.dict(os.environ, {"FORCE": "1"})

    call_command(command)


def test_inplace_to_s3_without_source():
    with pytest.raises(CommandError):
        call_command("inplace_to_s3")


def test_inplace_to_s3_dryrun(factories):
    upload = factories["music.Upload"](in_place=True, source="file:///music/music.mp3")
    call_command("inplace_to_s3", "--source", "/music")
    assert upload.source == "file:///music/music.mp3"
    assert not upload.audio_file


data = [
    {
        "file": "/music/test.mp3",
        "source": "/",
        "target": None,
        "expected": "/music/test.mp3",
    },
    {
        "file": "/music/test.mp3",
        "source": "/music",
        "target": "/in-place",
        "expected": "/in-place/test.mp3",
    },
    {
        "file": "/music/test.mp3",
        "source": "/music",
        "target": "/in-place/music",
        "expected": "/in-place/music/test.mp3",
    },
    {"file": "/music/test.mp3", "source": "/abcd", "target": "/music", "expected": "0"},
]


@pytest.mark.parametrize("data", data)
def test_inplace_to_s3(factories, data):
    out = StringIO()
    factories["music.Upload"](in_place=True, source=f"file://{data['file']}")
    if data["target"]:
        call_command(
            "inplace_to_s3",
            "--source",
            data["source"],
            "--target",
            data["target"],
            stdout=out,
        )
    else:
        call_command("inplace_to_s3", "--source", data["source"], stdout=out)
    assert data["expected"] in out.getvalue()
