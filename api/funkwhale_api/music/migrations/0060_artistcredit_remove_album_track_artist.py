# Generated manually for ArtistCredit multi-artist support

import django.contrib.postgres.search
from django.db import migrations, models, connection
import django.db.models.deletion
import django.utils.timezone
import uuid

from funkwhale_api.federation import utils as federation_utils
from django.conf import settings


def skip(apps, schema_editor):
    pass


def _artistcredit_fid(new_uuid):
    # Avoid reverse() dependency on federation:music:artistcredit-detail
    # so migration works even if that route is registered later.
    base = getattr(settings, "FUNKWHALE_URL", "http://localhost").rstrip("/")
    return f"{base}/federation/music/artistcredit/{new_uuid}"


def save_artist_credit(obj, ArtistCredit):
    if obj.artist_id is None:
        return None
    new_uuid = uuid.uuid4()
    artist_credit, created = ArtistCredit.objects.get_or_create(
        artist_id=obj.artist_id,
        joinphrase="",
        credit=obj.artist.name,
        index=0,
        defaults={
            "uuid": new_uuid,
            "fid": _artistcredit_fid(new_uuid),
        },
    )
    return (obj.pk, artist_credit.pk)


def bulk_save_m2m(model, relations, obj_name):
    table = model.artist_credit.through._meta.db_table

    values_sql = ", ".join(["(%s, %s)"] * len(relations))
    params = [x for pair in relations for x in pair]

    query = f"""
        INSERT INTO {table} ({obj_name}_id, artistcredit_id)
        VALUES {values_sql}
        ON CONFLICT DO NOTHING
    """

    with connection.cursor() as cursor:
        cursor.execute(query, params)


def set_all_artists_credit(apps, schema_editor):
    Track = apps.get_model("music", "Track")
    Album = apps.get_model("music", "Album")
    ArtistCredit = apps.get_model("music", "ArtistCredit")

    relations = []
    for track in Track.objects.select_related("artist").iterator(chunk_size=500):
        pair = save_artist_credit(track, ArtistCredit)
        if pair:
            relations.append(pair)
        if len(relations) >= 1000:
            bulk_save_m2m(Track, relations, "track")
            relations = []
    if relations:
        bulk_save_m2m(Track, relations, "track")

    relations = []
    for album in Album.objects.select_related("artist").iterator(chunk_size=500):
        pair = save_artist_credit(album, ArtistCredit)
        if pair:
            relations.append(pair)
        if len(relations) >= 1000:
            bulk_save_m2m(Album, relations, "album")
            relations = []
    if relations:
        bulk_save_m2m(Album, relations, "album")


class Migration(migrations.Migration):
    dependencies = [
        ("music", "0059_keep_transcoding_cache_by_default"),
        ("federation", "0028_auto_20221027_1141"),
    ]

    operations = [
        migrations.CreateModel(
            name="ArtistCredit",
            fields=[
                (
                    "id",
                    models.AutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "fid",
                    models.URLField(
                        db_index=True, max_length=500, null=True, unique=True
                    ),
                ),
                (
                    "mbid",
                    models.UUIDField(blank=True, db_index=True, null=True, unique=True),
                ),
                (
                    "uuid",
                    models.UUIDField(db_index=True, default=uuid.uuid4, unique=True),
                ),
                (
                    "creation_date",
                    models.DateTimeField(
                        db_index=True, default=django.utils.timezone.now
                    ),
                ),
                (
                    "body_text",
                    django.contrib.postgres.search.SearchVectorField(blank=True),
                ),
                ("credit", models.CharField(blank=True, max_length=500, null=True)),
                ("joinphrase", models.CharField(blank=True, max_length=250, null=True)),
                ("index", models.IntegerField(blank=True, null=True)),
                (
                    "artist",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="artist_credit",
                        to="music.artist",
                    ),
                ),
                (
                    "from_activity",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        to="federation.activity",
                    ),
                ),
            ],
            options={
                "ordering": ["index", "credit"],
            },
        ),
        migrations.AddField(
            model_name="album",
            name="artist_credit",
            field=models.ManyToManyField(
                related_name="albums",
                to="music.artistcredit",
            ),
        ),
        migrations.AddField(
            model_name="track",
            name="artist_credit",
            field=models.ManyToManyField(
                related_name="tracks",
                to="music.artistcredit",
            ),
        ),
        migrations.RunPython(set_all_artists_credit, skip),
        migrations.RemoveField(
            model_name="album",
            name="artist",
        ),
        migrations.RemoveField(
            model_name="track",
            name="artist",
        ),
    ]
