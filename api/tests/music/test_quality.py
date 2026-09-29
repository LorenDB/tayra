"""Tests for progressive multi-quality ladder helpers."""

import os
import tempfile

import pytest
from django.db import transaction

from funkwhale_api.music import quality


def test_normalize_quality():
    assert quality.normalize_quality("HIGH") == "high"
    assert quality.normalize_quality("original") == "original"
    assert quality.normalize_quality("nope") is None
    assert quality.normalize_quality(None) is None


def test_profile_for_quality():
    assert quality.profile_for_quality("original") == (None, None)
    fmt, br = quality.profile_for_quality("medium")
    assert fmt == "mp3"
    assert br == 128000
    fmt, br = quality.profile_for_quality("low")
    assert fmt == "mp3"
    assert br == 96000
    fmt, br = quality.profile_for_quality("high")
    assert fmt == "mp3"
    assert br == 256000


def test_quality_order_covers_profiles():
    assert quality.QUALITY_ORDER[0] == "original"
    for tier in quality.QUALITY_PROFILES:
        assert tier in quality.QUALITY_ORDER


def test_prewarm_tiers_cover_ladder():
    assert set(quality.PREWARM_TIERS) == {"high", "medium", "low"}


def test_is_ladder_version(factories):
    ladder = factories["music.UploadVersion"](bitrate=256000, mimetype="audio/mpeg")
    ad_hoc = factories["music.UploadVersion"](bitrate=111000, mimetype="audio/mpeg")
    assert quality.is_ladder_version(ladder) is True
    assert quality.is_ladder_version(ad_hoc) is False


def test_serialize_audio_qualities_structure(factories, preferences):
    preferences["music__transcoding_enabled"] = True
    upload = factories["music.Upload"](
        import_status="finished",
        bitrate=900000,
        mimetype="audio/flac",
    )
    items = quality.serialize_audio_qualities(upload)
    ids = [i["id"] for i in items]
    assert "original" in ids
    assert "high" in ids
    assert "medium" in ids
    assert "low" in ids
    original = next(i for i in items if i["id"] == "original")
    assert original["ready"] is True
    assert "quality=original" in original["listen_url"]
    assert "download=false" in original["listen_url"]
    high = next(i for i in items if i["id"] == "high")
    # Cold library: high not ready until prewarm/transcode.
    assert high["ready"] is False
    assert high["bitrate"] == 256000


def test_resolve_serve_file_original(factories, preferences):
    preferences["music__transcoding_enabled"] = True
    upload = factories["music.Upload"](
        import_status="finished",
        bitrate=192000,
        mimetype="audio/mpeg",
    )
    resolved = quality.resolve_serve_file(upload, quality="original")
    assert resolved["file"] is upload
    assert resolved["served_quality"] == "original"
    assert resolved["pending"] is False


def test_resolve_serve_file_pending_when_missing(factories, preferences):
    preferences["music__transcoding_enabled"] = True
    upload = factories["music.Upload"](
        import_status="finished",
        bitrate=900000,
        mimetype="audio/flac",
    )
    resolved = quality.resolve_serve_file(upload, quality="medium")
    assert resolved["pending"] is True
    assert resolved["format"] == "mp3"
    assert resolved["max_bitrate"] == 128000
    # Falls back to original when no derivative ready
    assert resolved["file"] is upload
    assert resolved["served_quality"] == "original"


def _fake_ffmpeg(payload):
    def _encode(input_path, output_path, output_format, bitrate_bps):
        with open(output_path, "wb") as handle:
            handle.write(payload)
        return output_path

    return _encode


@pytest.mark.django_db(transaction=True)
def test_ffmpeg_runs_before_any_version_row(factories, mocker):
    upload = factories["music.Upload"](
        import_status="finished",
        bitrate=900000,
        mimetype="audio/flac",
    )
    seen = {}

    def encode(input_path, output_path, output_format, bitrate_bps):
        seen["in_atomic"] = transaction.get_connection().in_atomic_block
        seen["versions"] = upload.versions.count()
        with open(output_path, "wb") as handle:
            handle.write(b"encoded-bytes")
        return output_path

    mocker.patch.object(quality, "transcode_with_ffmpeg", side_effect=encode)
    fd, source = tempfile.mkstemp(suffix=".flac")
    os.close(fd)
    mocker.patch.object(quality, "_input_path_for_upload", return_value=source)

    try:
        version = quality.create_transcoded_version_ffmpeg(
            upload, "audio/mpeg", "mp3", 128000
        )
    finally:
        os.remove(source)

    assert seen["in_atomic"] is False
    assert seen["versions"] == 0
    version.refresh_from_db()
    assert version.size == len(b"encoded-bytes")
    assert version.bitrate == 128000
    assert upload.versions.filter(size=0).count() == 0
    with version.audio_file.open("rb") as stored:
        assert stored.read() == b"encoded-bytes"


def test_failed_ffmpeg_leaves_no_version_row(factories, mocker):
    upload = factories["music.Upload"](
        import_status="finished", bitrate=900000, mimetype="audio/flac"
    )
    mocker.patch.object(
        quality,
        "transcode_with_ffmpeg",
        side_effect=RuntimeError("ffmpeg failed"),
    )
    fd, source = tempfile.mkstemp(suffix=".flac")
    os.close(fd)
    mocker.patch.object(quality, "_input_path_for_upload", return_value=source)

    try:
        with pytest.raises(RuntimeError, match="ffmpeg failed"):
            quality.create_transcoded_version_ffmpeg(
                upload, "audio/mpeg", "mp3", 128000
            )
    finally:
        os.remove(source)

    assert upload.versions.count() == 0


def test_second_encode_reuses_ready_version(factories, mocker):
    upload = factories["music.Upload"](
        import_status="finished", bitrate=900000, mimetype="audio/flac"
    )
    encode = mocker.patch.object(
        quality, "transcode_with_ffmpeg", side_effect=_fake_ffmpeg(b"once")
    )
    fd, source = tempfile.mkstemp(suffix=".flac")
    os.close(fd)
    mocker.patch.object(quality, "_input_path_for_upload", return_value=source)

    try:
        first = quality.create_transcoded_version_ffmpeg(
            upload, "audio/mpeg", "mp3", 128000
        )
        second = quality.create_transcoded_version_ffmpeg(
            upload, "audio/mpeg", "mp3", 128000
        )
    finally:
        os.remove(source)

    assert second.pk == first.pk
    assert encode.call_count == 1


def test_persist_returns_existing_row_when_insert_races(factories, mocker):
    upload = factories["music.Upload"](bitrate=320000, mimetype="audio/flac")
    winner = factories["music.UploadVersion"](
        upload=upload, bitrate=128000, mimetype="audio/mpeg", size=4096
    )
    real_find = quality.find_transcoded_version
    calls = {"n": 0}

    def hide_then_find(candidate, fmt, max_bitrate=None):
        calls["n"] += 1
        # Pre-check and in-transaction re-check both miss; the conflict
        # handler must still observe the committed row.
        if calls["n"] <= 2:
            return None
        return real_find(candidate, fmt, max_bitrate=max_bitrate)

    mocker.patch.object(quality, "find_transcoded_version", side_effect=hide_then_find)
    fd, path = tempfile.mkstemp(suffix=".mp3")
    os.close(fd)
    try:
        with open(path, "wb") as handle:
            handle.write(b"loser")
        found = quality.persist_encoded_version(
            upload, "audio/mpeg", "mp3", 128000, path, download_name="track.mp3"
        )
    finally:
        os.remove(path)

    assert found.pk == winner.pk
    assert upload.versions.filter(bitrate=128000).count() == 1


def test_pydub_transcode_inserts_after_export(factories, mocker):
    upload = factories["music.Upload"](bitrate=320000, mimetype="audio/mpeg")
    seen = {}

    class _Audio:
        def export(self, path, format, bitrate):
            seen["versions"] = upload.versions.count()
            with open(path, "wb") as handle:
                handle.write(b"pydub-bytes")

    mocker.patch.object(upload, "get_audio_segment", return_value=_Audio())
    version = upload.create_transcoded_version("audio/mpeg", "mp3", 128000)

    assert seen["versions"] == 0
    assert version.size == len(b"pydub-bytes")
    assert upload.versions.count() == 1
