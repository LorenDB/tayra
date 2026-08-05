import click

from funkwhale_api.tags import tasks

from . import base


@base.cli.group()
def tags():
    """Manage tags / genres"""
    pass


@tags.command(name="sync-musicbrainz-genres")
def sync_musicbrainz_genres():
    """
    Fetch official MusicBrainz genres and upsert them into the Tag table (with mbid).

    Respects MusicBrainz rate limits (~1 req/s); first run may take several minutes.
    Also scheduled monthly via Celery beat (tags.update_musicbrainz_genre).
    """
    click.echo("Fetching MusicBrainz genres…")
    result = tasks.update_musicbrainz_genre()
    click.echo(
        f"  Done: {result.get('created', 0)} created, "
        f"{result.get('updated', 0)} updated "
        f"({result.get('fetched', 0)} genres from MusicBrainz)"
    )
