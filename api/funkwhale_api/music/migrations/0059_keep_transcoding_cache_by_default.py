"""Keep multi-quality transcodes by default.

Previous default retained derivatives for 7 days (10080 minutes). Ladder
rungs are now pre-warmed in the background and should not be discarded
unless an admin explicitly sets a positive cache duration.
"""

from django.db import migrations

# Old registry default: 60 * 24 * 7 minutes.
_OLD_DEFAULT_MINUTES = "10080"


def disable_default_transcode_gc(apps, schema_editor):
    GlobalPreferenceModel = apps.get_model(
        "dynamic_preferences", "GlobalPreferenceModel"
    )
    # Only flip the historical default so intentional custom values stay put.
    GlobalPreferenceModel.objects.filter(
        section="music",
        name="transcoding_cache_duration",
        raw_value=_OLD_DEFAULT_MINUTES,
    ).update(raw_value="0")


def restore_old_default(apps, schema_editor):
    GlobalPreferenceModel = apps.get_model(
        "dynamic_preferences", "GlobalPreferenceModel"
    )
    GlobalPreferenceModel.objects.filter(
        section="music",
        name="transcoding_cache_duration",
        raw_value="0",
    ).update(raw_value=_OLD_DEFAULT_MINUTES)


class Migration(migrations.Migration):

    dependencies = [
        ("music", "0058_album_duration"),
        ("dynamic_preferences", "0006_auto_20191001_2236"),
    ]

    operations = [
        migrations.RunPython(disable_default_transcode_gc, restore_old_default),
    ]
