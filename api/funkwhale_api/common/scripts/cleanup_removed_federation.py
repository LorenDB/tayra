"""
Drop tables and columns left behind by the removed federation, moderation and
subsonic features.

Only needed on databases that existed before the removal: the migration history
was rewritten, so `migrate` on an upgraded database adds the new columns but
never drops the old federation/moderation tables or the removed columns.
Fresh installs do not need this script (it is a no-op).

Usage:

    funkwhale-manage script cleanup_removed_federation

"""

from django.db import connection

FEDERATION_TABLES = [
    "federation_activity",
    "federation_actor",
    "federation_delivery",
    "federation_domain",
    "federation_fetch",
    "federation_follow",
    "federation_inboxitem",
    "federation_library",
    "federation_libraryfollow",
    "federation_librarytrack",
]

MODERATION_TABLES = [
    "moderation_instancepolicy",
    "moderation_note",
    "moderation_report",
    "moderation_userfilter",
    "moderation_userrequest",
]

ORPHANED_COLUMNS = {
    "audio_channel": ["actor_id", "attributed_to_id"],
    "common_attachment": ["actor_id"],
    "music_album": ["fid", "from_activity_id", "attributed_to_id"],
    "music_artist": ["fid", "from_activity_id", "attributed_to_id"],
    "music_artistcredit": ["fid", "from_activity_id"],
    "music_importjob": ["library_track_id"],
    "music_library": ["fid", "followers_url", "actor_id"],
    "music_libraryscan": ["actor_id"],
    "music_track": ["fid", "from_activity_id", "attributed_to_id"],
    "music_trackactor": ["actor_id"],
    "music_upload": ["from_activity_id"],
    "users_user": ["subsonic_api_token", "actor_id"],
}


def main(command, **kwargs):
    with connection.cursor() as cursor:
        for table in FEDERATION_TABLES + MODERATION_TABLES:
            cursor.execute("SELECT to_regclass(%s)", (table,))
            if cursor.fetchone()[0]:
                command.stdout.write(f"Dropping table {table}…")
                cursor.execute(f'DROP TABLE IF EXISTS "{table}" CASCADE')
            else:
                command.stdout.write(f"Table {table} already gone, skipping")

        for table, columns in ORPHANED_COLUMNS.items():
            cursor.execute("SELECT to_regclass(%s)", (table,))
            if not cursor.fetchone()[0]:
                command.stdout.write(f"Table {table} does not exist, skipping")
                continue
            for column in columns:
                cursor.execute(
                    "SELECT column_name FROM information_schema.columns "
                    "WHERE table_schema = 'public' AND table_name = %s "
                    "AND column_name = %s",
                    (table, column),
                )
                if cursor.fetchone():
                    command.stdout.write(f"Dropping column {table}.{column}…")
                    cursor.execute(
                        f'ALTER TABLE "{table}" DROP COLUMN IF EXISTS "{column}"'
                    )
                else:
                    command.stdout.write(
                        f"Column {table}.{column} already gone, skipping"
                    )

    command.stdout.write(
        command.style.SUCCESS(
            "Done. Old federation/moderation/subsonic schema removed."
        )
    )
