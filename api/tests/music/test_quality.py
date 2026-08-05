"""Tests for progressive multi-quality ladder helpers."""

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
    ladder = factories["music.UploadVersion"](
        bitrate=256000, mimetype="audio/mpeg"
    )
    ad_hoc = factories["music.UploadVersion"](
        bitrate=111000, mimetype="audio/mpeg"
    )
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
