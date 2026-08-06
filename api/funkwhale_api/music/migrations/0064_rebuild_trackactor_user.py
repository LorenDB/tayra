# -*- coding: utf-8 -*-
"""
Recovery for databases whose music_trackactor.actor_id was dropped before
music.0063_trackactor_actor_to_user could rename it (e.g. an early version of
the cleanup_removed_federation script listed trackactor.actor_id).

Those databases end up with music_trackactor missing its user FK entirely:
0063 no-ops (no actor_id to rename) and the new code queries a user_id column
that never gets created. This migration recreates the column and rebuilds the
denormalized permission cache so access control is correct again.

Databases in the normal state (user_id present) are untouched.
"""

from django.conf import settings
from django.db import migrations, models


def _column_exists(cursor, table, column):
    cursor.execute(
        "SELECT COUNT(*) FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = %s AND column_name = %s",
        (table, column),
    )
    return cursor.fetchone()[0] > 0


def forward(apps, schema_editor):
    TrackActor = apps.get_model("music", "TrackActor")
    connection = schema_editor.connection
    with connection.cursor() as cursor:
        if _column_exists(cursor, "music_trackactor", "user_id"):
            # normal state (renamed by 0063, or fresh database)
            return

        field = TrackActor._meta.get_field("user")
        schema_editor.add_field(TrackActor, field)

    # Rebuild the denormalization cache: rows lost their user mapping when the
    # old column was dropped. get_objs/create_entries use the current schema,
    # which is fully migrated by this point.
    from funkwhale_api.music.models import Library, TrackActor as LiveTrackActor

    for library in Library.objects.all():
        LiveTrackActor.create_entries(library, delete_existing=True)


def backward(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    # non-atomic: the rebuild inserts rows against a table whose track/upload
    # FKs are DEFERRABLE INITIALLY DEFERRED; a single wrapping transaction
    # would leave pending trigger events and break the deferred CREATE INDEX.
    atomic = False

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("music", "0063_trackactor_actor_to_user"),
        # the rebuild touches the live User model, which needs the columns
        # added by users.0030 (avatar_attachment, summary_obj)
        ("users", "0030_auto_20260806_1305"),
    ]

    operations = [
        migrations.RunPython(forward, backward),
    ]
