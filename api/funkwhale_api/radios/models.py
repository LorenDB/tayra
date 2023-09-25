from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.core.serializers.json import DjangoJSONEncoder
from django.db import models
from django.db.models import JSONField
from django.utils import timezone

from funkwhale_api.music.models import Track

from . import filters


class Radio(models.Model):
    CONFIG_VERSION = 0
    user = models.ForeignKey(
        "users.User",
        related_name="radios",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
    )
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    creation_date = models.DateTimeField(default=timezone.now)
    is_public = models.BooleanField(default=False)
    version = models.PositiveIntegerField(default=0)
    config = JSONField(encoder=DjangoJSONEncoder)

    def get_candidates(self):
        return filters.run(self.config)


class RadioSession(models.Model):
    user = models.ForeignKey(
        "users.User",
        related_name="radio_sessions",
        null=True,
        blank=True,
        on_delete=models.CASCADE,
    )
    session_key = models.CharField(max_length=100, null=True, blank=True)
    radio_type = models.CharField(max_length=50)
    custom_radio = models.ForeignKey(
        Radio, related_name="sessions", null=True, blank=True, on_delete=models.CASCADE
    )
    creation_date = models.DateTimeField(default=timezone.now)
    related_object_content_type = models.ForeignKey(
        ContentType, blank=True, null=True, on_delete=models.CASCADE
    )
    related_object_id = models.PositiveIntegerField(blank=True, null=True)
    related_object = GenericForeignKey(
        "related_object_content_type", "related_object_id"
    )
    CONFIG_VERSION = 0
    config = JSONField(encoder=DjangoJSONEncoder, blank=True, null=True)

    @property
    def next_position(self):
        next_position = 1

        last_session_track = self.session_tracks.all().order_by("-position").first()
        if last_session_track:
            next_position = last_session_track.position + 1

        return next_position

    def add(self, tracks):
        next_position = self.next_position
        radio_session_tracks = []
        for i, track in enumerate(tracks):
            radio_session_track = RadioSessionTrack(
                track=track, session=self, position=next_position + i
            )
            radio_session_tracks.append(radio_session_track)

        new_session_tracks = RadioSessionTrack.objects.bulk_create(radio_session_tracks)

        return new_session_tracks

    def radio(self, api_version):
        if api_version == 2:
            from .registries_v2 import registry
        else:
            from .registries import registry

        return registry[self.radio_type](session=self)


class RadioSessionTrack(models.Model):
    session = models.ForeignKey(
        RadioSession, related_name="session_tracks", on_delete=models.CASCADE
    )
    position = models.IntegerField(default=1)
    track = models.ForeignKey(
        Track, related_name="radio_session_tracks", on_delete=models.CASCADE
    )

    class Meta:
        ordering = ("session", "position")
        unique_together = ("session", "position")
