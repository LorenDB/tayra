# -*- coding: utf-8 -*-
"""
Upgrade helper for databases that predate the federation removal.

Mutation.created_by / approved_by were rewritten from federation.Actor to
users.User by editing the historical migrations, so a plain ``migrate`` on an
existing database keeps FK constraints pointing at federation_actor, which
reject user ids written by the new code.

Fresh databases never had those constraints and this migration is a no-op there.
"""

from django.db import migrations


def _column_exists(cursor, table, column):
    cursor.execute(
        "SELECT COUNT(*) FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = %s AND column_name = %s",
        (table, column),
    )
    return cursor.fetchone()[0] > 0


def forward(apps, schema_editor):
    connection = schema_editor.connection
    with connection.cursor() as cursor:
        if not _column_exists(cursor, "common_mutation", "created_by_id"):
            return

        # the old FKs would reject user ids written by the new code
        cursor.execute("SELECT to_regclass('federation_actor')")
        has_federation_actor = cursor.fetchone()[0] is not None
        if has_federation_actor:
            cursor.execute(
                "SELECT conname FROM pg_constraint "
                "WHERE conrelid = 'common_mutation'::regclass "
                "AND contype = 'f' AND confrelid = 'federation_actor'::regclass"
            )
            for (conname,) in cursor.fetchall():
                cursor.execute(
                    f'ALTER TABLE "common_mutation" DROP CONSTRAINT "{conname}"'
                )
            # Backfill: users_user.actor_id is the reverse FK to
            # federation_actor, so existing mutations created by local users
            # map to the matching user. Rows that referenced remote actors are
            # left NULL (read-only history).
            cursor.execute(
                "SELECT COUNT(*) FROM information_schema.columns "
                "WHERE table_schema = 'public' AND table_name = 'users_user' "
                "AND column_name = 'actor_id'"
            )
            if cursor.fetchone()[0] > 0:
                for column in ("created_by_id", "approved_by_id"):
                    cursor.execute(
                        f'UPDATE "common_mutation" SET "{column}" = uu."id" '
                        f'FROM "users_user" uu '
                        f'WHERE uu."actor_id" = "common_mutation"."{column}"'
                    )


def backward(apps, schema_editor):
    pass


class Migration(migrations.Migration):
    dependencies = [
        ("common", "0011_auto_20260806_1305"),
    ]

    operations = [
        migrations.RunPython(forward, backward),
    ]
