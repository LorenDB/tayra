import uuid

from django.core.serializers.json import DjangoJSONEncoder
from django.db import models
from django.db.models import JSONField
from django.db.models.signals import post_delete
from django.dispatch import receiver
from django.urls import reverse
from django.utils import timezone

from funkwhale_api.common import utils as common_utils


def empty_dict():
    return {}


class ChannelQuerySet(models.QuerySet):
    def external_rss(self, include=True):
        if include:
            return self.filter(is_external_rss=True)
        return self.exclude(is_external_rss=True)

    def subscribed(self, user):
        if not user:
            return self.none()

        subscriptions = ChannelSubscription.objects.filter(user=user, approved=True)
        return self.filter(pk__in=subscriptions.values_list("channel_id", flat=True))


class Channel(models.Model):
    uuid = models.UUIDField(default=uuid.uuid4, unique=True)
    artist = models.OneToOneField(
        "music.Artist", on_delete=models.CASCADE, related_name="channel"
    )
    # the owner of the channel (None for external RSS feeds)
    owner = models.ForeignKey(
        "users.User",
        on_delete=models.CASCADE,
        related_name="owned_channels",
        null=True,
        blank=True,
    )
    preferred_username = models.CharField(max_length=255, unique=True, db_index=True)
    # True when the channel was imported from an external RSS feed
    is_external_rss = models.BooleanField(default=False)

    library = models.OneToOneField(
        "music.Library", on_delete=models.CASCADE, related_name="channel"
    )
    creation_date = models.DateTimeField(default=timezone.now)
    rss_url = models.URLField(max_length=500, null=True, blank=True)

    # metadata to enhance rss feed
    metadata = JSONField(
        default=empty_dict, max_length=50000, encoder=DjangoJSONEncoder, blank=True
    )

    objects = ChannelQuerySet.as_manager()

    @property
    def is_local(self) -> bool:
        return True

    def get_absolute_url(self):
        return common_utils.full_url(f"/channels/{self.preferred_username}")

    def get_rss_url(self):
        if self.is_external_rss:
            return self.rss_url

        return common_utils.full_url(
            reverse(
                "api:v1:channels-rss",
                kwargs={"composite": self.preferred_username},
            )
        )


class ChannelSubscription(models.Model):
    uuid = models.UUIDField(default=uuid.uuid4, unique=True)
    user = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="channel_subscriptions"
    )
    channel = models.ForeignKey(
        Channel, on_delete=models.CASCADE, related_name="subscriptions"
    )
    approved = models.BooleanField(default=True)
    creation_date = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ("user", "channel")


@receiver(post_delete, sender=Channel)
def delete_channel_related_objs(instance, **kwargs):
    instance.library.delete()
    instance.artist.delete()
