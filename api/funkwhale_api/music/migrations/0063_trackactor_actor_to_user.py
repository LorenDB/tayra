# -*- coding: utf-8 -*-
"""
Upgrade helper for databases that predate the federation removal.

The TrackActor.actor (federation.Actor) FK was rewritten to TrackActor.user
(users.User) by editing the historical migrations, so a plain ``migrate`` on an
existing database leaves the new code querying a missing ``user_id`` column.

Fresh databases never had ``actor_id`` and this migration is a no-op there.
"""

from django.db import migrations


def _column_exists(cursor, table, column):
    cursor.execute(
        "SELECT COUNT(*) FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = %s AND column_name = %s",
        (table, column),
    )
    return cursor.fetchone()[0] > 0


def _drop_federation_fks(cursor, table):
    cursor.execute("SELECT to_regclass('federation_actor')")
    if cursor.fetchone()[0] is None:
        return
    cursor.execute(
        "SELECT conname FROM pg_constraint "
        "WHERE conrelid = %s::regclass "
        "AND contype = 'f' AND confrelid = 'federation_actor'::regclass",
        (table,),
    )
    for (conname,) in cursor.fetchall():
        cursor.execute(f'ALTER TABLE "{table}" DROP CONSTRAINT "{conname}"')


def forward(apps, schema_editor):
    connection = schema_editor.connection
    with connection.cursor() as cursor:
        if not _column_exists(cursor, "music_trackactor", "actor_id"):
            # fresh database: user_id was created by the rewritten history
            return

        # the old FK would reject user ids written by the new code
        _drop_federation_fks(cursor, "music_trackactor")

        cursor.execute(
            'ALTER TABLE "music_trackactor" RENAME COLUMN "actor_id" TO "user_id"'
        )

        # Backfill from the old actors: users_user.actor_id is the reverse FK
        # to federation_actor, so permission rows recorded for a local actor
        # map to the matching user.
        cursor.execute(
            "SELECT COUNT(*) FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = 'users_user' "
            "AND column_name = 'actor_id'"
        )
        if cursor.fetchone()[0] > 0:
            cursor.execute(
                'UPDATE "music_trackactor" SET "user_id" = uu."id" '
                'FROM "users_user" uu '
                'WHERE uu."actor_id" = "music_trackactor"."user_id"'
            )


def backward(apps, schema_editor):
    connection = schema_editor.connection
    with connection.cursor() as cursor:
        if not _column_exists(cursor, "music_trackactor", "user_id"):
            return
        cursor.execute(
            'ALTER TABLE "music_trackactor" RENAME COLUMN "user_id" TO "actor_id"'
        )


class Migration(migrations.Migration):
    dependencies = [
        ("music", "0062_alter_library_owner"),
    ]

    operations = [
        migrations.RunPython(forward, backward),
    ]
