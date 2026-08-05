"""Multi-quality audio ladder for progressive streaming.

Maps product tiers (original / high / medium / low) to encode profiles and
resolves the best *ready* progressive file without blocking the HTTP request
on a cold transcode when possible.
"""

from __future__ import annotations

import logging
import os
import subprocess
import tempfile

from django.core.files.base import ContentFile
from django.db import transaction
from django.utils import timezone

from . import utils

logger = logging.getLogger(__name__)

# Product tiers → encode profile (format extension, bitrate bps).
# ``original`` is a sentinel: serve the source upload as-is.
QUALITY_PROFILES = {
    "high": {"format": "mp3", "bitrate": 256000},
    "medium": {"format": "mp3", "bitrate": 128000},
    "low": {"format": "mp3", "bitrate": 96000},
}

QUALITY_ORDER = ("original", "high", "medium", "low")

# Pre-warm these rungs after import / first play (when source is higher quality).
PREWARM_TIERS = ("high", "medium")


def normalize_quality(value):
    if not value:
        return None
    value = str(value).strip().lower()
    if value == "original":
        return "original"
    if value in QUALITY_PROFILES:
        return value
    return None


def profile_for_quality(quality):
    """Return (format, max_bitrate_bps) or (None, None) for original/unknown."""
    quality = normalize_quality(quality)
    if not quality or quality == "original":
        return None, None
    profile = QUALITY_PROFILES[quality]
    return profile["format"], profile["bitrate"]


def find_transcoded_version(upload, format, max_bitrate=None):
    """Return an existing UploadVersion or None (never creates)."""
    if format:
        mimetype = utils.EXTENSION_TO_MIMETYPE.get(format)
        if not mimetype:
            return None
    else:
        mimetype = upload.mimetype or "audio/mpeg"
        format = utils.MIMETYPE_TO_EXTENSION.get(mimetype)
        if not format:
            return None

    existing_versions = upload.versions.filter(mimetype=mimetype, size__gt=0)
    if max_bitrate is not None:
        acceptable_max_bitrate = max_bitrate * 1.2
        acceptable_min_bitrate = max_bitrate * 0.8
        existing_versions = existing_versions.filter(
            bitrate__gte=acceptable_min_bitrate, bitrate__lte=acceptable_max_bitrate
        ).order_by("-bitrate")
    if existing_versions:
        return existing_versions[0]
    return None


def find_any_version_for_format(upload, format):
    """Any non-empty version for the given format, highest bitrate first."""
    mimetype = utils.EXTENSION_TO_MIMETYPE.get(format)
    if not mimetype:
        return None
    return (
        upload.versions.filter(mimetype=mimetype, size__gt=0)
        .order_by("-bitrate")
        .first()
    )


def find_best_ready_at_or_below(upload, quality):
    """
    Best ready progressive source for *quality* or a lower tier.

    Returns (file_like, served_quality_label) where file_like is Upload or
    UploadVersion.
    """
    quality = normalize_quality(quality) or "original"
    if quality == "original":
        return upload, "original"

    try:
        start = QUALITY_ORDER.index(quality)
    except ValueError:
        return upload, "original"

    # Prefer exact tier, then step down the ladder (higher index = lower quality).
    for tier in QUALITY_ORDER[start:]:
        if tier == "original":
            continue
        fmt, bitrate = profile_for_quality(tier)
        version = find_transcoded_version(upload, fmt, max_bitrate=bitrate)
        if version:
            return version, tier

    # Any mp3 (or profile format) version is better than huge original for low tiers.
    for tier in ("high", "medium", "low"):
        fmt, _ = profile_for_quality(tier)
        version = find_any_version_for_format(upload, fmt)
        if version:
            return version, tier

    return upload, "original"


def needs_transcode(upload, format, max_bitrate=None):
    """True when the source is not already acceptable for the request.

    Mirrors ``views.should_transcode`` but lives here to avoid circular imports.
    """
    from funkwhale_api.common import preferences

    if not preferences.get("music__transcoding_enabled"):
        return False
    format_need_transcoding = True
    bitrate_need_transcoding = True
    if format is None:
        format_need_transcoding = False
    elif format not in utils.EXTENSION_TO_MIMETYPE:
        format_need_transcoding = False
    elif upload.mimetype is None:
        format_need_transcoding = False
    elif upload.mimetype == utils.EXTENSION_TO_MIMETYPE[format]:
        format_need_transcoding = False

    if max_bitrate is None:
        bitrate_need_transcoding = False
    elif not upload.bitrate:
        bitrate_need_transcoding = False
    elif upload.bitrate <= max_bitrate:
        bitrate_need_transcoding = False

    return format_need_transcoding or bitrate_need_transcoding


def _input_path_for_upload(upload):
    if upload.audio_file:
        try:
            return upload.audio_file.path
        except NotImplementedError:
            # Remote storage — download to temp not implemented here.
            return None
    if upload.source and upload.source.startswith("file://"):
        path = utils.resolve_inplace_source(upload.source)
        return str(path) if path is not None else None
    return None


def transcode_with_ffmpeg(input_path, output_path, output_format, bitrate_bps):
    """Encode *input_path* to *output_path* using ffmpeg CLI."""
    bitrate_k = max(32, int(bitrate_bps or 128000) // 1000)
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        input_path,
        "-vn",
        "-b:a",
        f"{bitrate_k}k",
    ]
    if output_format in ("m4a", "aac"):
        cmd.extend(["-c:a", "aac", "-movflags", "+faststart"])
        # normalize extension for ffmpeg
        if output_format == "aac":
            output_format = "m4a"
    elif output_format == "mp3":
        cmd.extend(["-c:a", "libmp3lame"])
    elif output_format in ("ogg", "opus"):
        cmd.extend(["-c:a", "libopus" if output_format == "opus" else "libvorbis"])
    else:
        # Let ffmpeg pick from extension
        pass

    cmd.append(output_path)
    result = subprocess.run(cmd, capture_output=True, timeout=600)
    if result.returncode != 0:
        stderr = (result.stderr or b"").decode("utf-8", errors="replace")[:500]
        raise RuntimeError(f"ffmpeg failed ({result.returncode}): {stderr}")
    return output_path


@transaction.atomic
def create_transcoded_version_ffmpeg(upload, mimetype, format, bitrate):
    """
    Create and persist an UploadVersion using ffmpeg (not pydub).

    Safe to call from Celery or a last-resort request path.
    """
    bitrate = min(bitrate or 320000, upload.bitrate or 320000)
    # Re-check under lock to avoid duplicate work.
    existing = find_transcoded_version(upload, format, max_bitrate=bitrate)
    if existing:
        return existing

    input_path = _input_path_for_upload(upload)
    if not input_path or not os.path.isfile(input_path):
        # Fall back to pydub path if we only have a file-like.
        return upload.create_transcoded_version(mimetype, format, bitrate)

    version = upload.versions.create(mimetype=mimetype, bitrate=bitrate, size=0)
    base = os.path.splitext(os.path.basename(input_path))[0]
    new_name = f"{base}.{format}"

    # Placeholder so FileField has a name/path on local storage.
    version.audio_file.save(new_name, ContentFile(b""), save=True)
    output_path = version.audio_file.path

    try:
        # Write to a sibling temp then replace, so a failed encode leaves size=0.
        fd, tmp_path = tempfile.mkstemp(
            suffix=f".{format}", dir=os.path.dirname(output_path) or None
        )
        os.close(fd)
        try:
            transcode_with_ffmpeg(input_path, tmp_path, format, bitrate)
            os.replace(tmp_path, output_path)
        finally:
            if os.path.exists(tmp_path):
                try:
                    os.remove(tmp_path)
                except OSError:
                    pass

        version.size = os.path.getsize(output_path)
        version.accessed_date = timezone.now()
        version.save(update_fields=["size", "accessed_date"])
        return version
    except Exception:
        # Clean up empty/failed version row + file
        try:
            if version.audio_file:
                version.audio_file.delete(save=False)
        except Exception:
            pass
        version.delete()
        raise


def ensure_transcoded_version_sync(upload, format, max_bitrate=None):
    """Find or create a version (blocking). Used by Celery and legacy clients."""
    if format:
        mimetype = utils.EXTENSION_TO_MIMETYPE[format]
    else:
        mimetype = upload.mimetype or "audio/mpeg"
        format = utils.MIMETYPE_TO_EXTENSION[mimetype]

    existing = find_transcoded_version(upload, format, max_bitrate=max_bitrate)
    if existing:
        return existing

    return create_transcoded_version_ffmpeg(
        upload, mimetype, format, bitrate=max_bitrate
    )


def resolve_serve_file(upload, format=None, max_bitrate=None, quality=None):
    """
    Resolve what to serve for a listen request.

    Returns dict:
      file: Upload or UploadVersion
      served_quality: str label
      pending: bool (requested derivative not ready; better version enqueued)
      format, max_bitrate: effective encode target if any
    """
    if quality:
        quality = normalize_quality(quality)
        if quality == "original":
            return {
                "file": upload,
                "served_quality": "original",
                "pending": False,
                "format": None,
                "max_bitrate": None,
            }
        if quality:
            format, max_bitrate = profile_for_quality(quality)

    if not needs_transcode(upload, format, max_bitrate=max_bitrate):
        return {
            "file": upload,
            "served_quality": quality or "original",
            "pending": False,
            "format": format,
            "max_bitrate": max_bitrate,
        }

    existing = find_transcoded_version(upload, format, max_bitrate=max_bitrate)
    if existing:
        return {
            "file": existing,
            "served_quality": quality or format or "transcoded",
            "pending": False,
            "format": format,
            "max_bitrate": max_bitrate,
        }

    # Not ready — enqueue async work (caller may also call delay).
    pending = True
    if quality:
        file_obj, served = find_best_ready_at_or_below(upload, quality)
        # If we still only have original and requested a lossy tier, mark pending.
        if served == "original" and quality != "original":
            pending = True
        else:
            pending = served != quality
        return {
            "file": file_obj,
            "served_quality": served,
            "pending": pending,
            "format": format,
            "max_bitrate": max_bitrate,
        }

    # Legacy to=/max_bitrate: prefer any format match, else original + pending.
    any_fmt = find_any_version_for_format(upload, format) if format else None
    if any_fmt:
        return {
            "file": any_fmt,
            "served_quality": format or "transcoded",
            "pending": True,
            "format": format,
            "max_bitrate": max_bitrate,
        }

    return {
        "file": upload,
        "served_quality": "original",
        "pending": True,
        "format": format,
        "max_bitrate": max_bitrate,
    }


def serialize_audio_qualities(upload, track_listen_url=None):
    """Build audio_qualities list for API serializers."""
    base = track_listen_url or (
        upload.track.listen_url if upload.track_id else None
    )
    if not base:
        return []

    sep = "&" if "?" in base else "?"
    results = []

    # Original
    results.append(
        {
            "id": "original",
            "bitrate": upload.bitrate,
            "mimetype": upload.mimetype,
            "ready": True,
            "listen_url": f"{base}{sep}quality=original&download=false",
        }
    )

    for tier, profile in QUALITY_PROFILES.items():
        fmt = profile["format"]
        br = profile["bitrate"]
        # Skip rungs that would upscale a lower-bitrate source.
        if upload.bitrate and upload.bitrate <= br * 0.9:
            # Source already at or below this tier — still advertise if same format.
            if upload.mimetype == utils.EXTENSION_TO_MIMETYPE.get(fmt):
                results.append(
                    {
                        "id": tier,
                        "bitrate": upload.bitrate,
                        "mimetype": upload.mimetype,
                        "ready": True,
                        "listen_url": f"{base}{sep}quality={tier}&download=false",
                    }
                )
            continue

        version = find_transcoded_version(upload, fmt, max_bitrate=br)
        results.append(
            {
                "id": tier,
                "bitrate": br,
                "mimetype": utils.EXTENSION_TO_MIMETYPE.get(fmt, "audio/mpeg"),
                "ready": version is not None,
                "listen_url": f"{base}{sep}quality={tier}&download=false",
            }
        )

    return results
