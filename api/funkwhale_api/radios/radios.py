import datetime
import json
import logging
import random
from typing import List, Optional, Tuple

from django.core.exceptions import ValidationError
from django.db import connection
from django.db.models import Q
from rest_framework import serializers

from funkwhale_api.federation import fields as federation_fields
from funkwhale_api.federation import models as federation_models
from funkwhale_api.moderation import filters as moderation_filters
from funkwhale_api.music.models import Artist, Library, Track, Upload
from funkwhale_api.radios import lb_recommendations
from funkwhale_api.tags.models import Tag

from . import filters, models
from .registries import registry

logger = logging.getLogger(__name__)


class SimpleRadio:
    related_object_field = None

    def clean(self, instance):
        return

    def pick(
        self, choices: List[int], previous_choices: Optional[List[int]] = None
    ) -> int:
        if previous_choices:
            choices = list(set(choices).difference(set(previous_choices)))
        return random.sample(choices, 1)[0]

    def pick_many(self, choices: List[int], quantity: int) -> int:
        return random.sample(list(set(choices)), quantity)

    def weighted_pick(
        self,
        choices: List[Tuple[int, int]],
        previous_choices: Optional[List[int]] = None,
    ) -> int:
        total = sum(weight for c, weight in choices)
        r = random.uniform(0, total)
        upto = 0
        for choice, weight in choices:
            if upto + weight >= r:
                return choice
            upto += weight


class SessionRadio(SimpleRadio):
    def __init__(self, session=None):
        self.session = session

    def start_session(self, user, **kwargs):
        self.session = models.RadioSession.objects.create(
            user=user, radio_type=self.radio_type, **kwargs
        )
        return self.session

    def get_queryset(self, **kwargs):
        qs = Track.objects.all()
        if not self.session:
            return qs
        if not self.session.user:
            return qs
        query = moderation_filters.get_filtered_content_query(
            config=moderation_filters.USER_FILTER_CONFIG["TRACK"],
            user=self.session.user,
        )
        return qs.exclude(query)

    def get_queryset_kwargs(self):
        return {}

    def get_choices(self, **kwargs):
        kwargs.update(self.get_queryset_kwargs())
        queryset = self.get_queryset(**kwargs)
        if self.session:
            queryset = self.filter_from_session(queryset)
            if kwargs.pop("filter_playable", True):
                queryset = queryset.playable_by(
                    self.session.user.actor if self.session.user else None
                )
        queryset = self.filter_queryset(queryset)
        return queryset

    def filter_queryset(self, queryset):
        return queryset

    def filter_from_session(self, queryset):
        already_played = self.session.session_tracks.all().values_list(
            "track", flat=True
        )
        queryset = queryset.exclude(pk__in=already_played)
        return queryset

    def pick(self, **kwargs):
        return self.pick_many(quantity=1, **kwargs)[0]

    def pick_many(self, quantity, **kwargs):
        choices = self.get_choices(**kwargs)
        picked_choices = super().pick_many(choices=choices, quantity=quantity)
        if self.session:
            for choice in picked_choices:
                self.session.add(choice)
        return picked_choices

    def validate_session(self, data, **context):
        return data


@registry.register(name="random")
class RandomRadio(SessionRadio):
    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        return qs.filter(artist__content_category="music").order_by("?")


@registry.register(name="random_library")
class RandomLibraryRadio(SessionRadio):
    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        tracks_ids = self.session.user.actor.attributed_tracks.all().values_list(
            "id", flat=True
        )
        query = Q(artist__content_category="music") & Q(pk__in=tracks_ids)
        return qs.filter(query).order_by("?")


@registry.register(name="favorites")
class FavoritesRadio(SessionRadio):
    def get_queryset_kwargs(self):
        kwargs = super().get_queryset_kwargs()
        if self.session:
            kwargs["user"] = self.session.user
        return kwargs

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        track_ids = kwargs["user"].track_favorites.all().values_list("track", flat=True)
        return qs.filter(pk__in=track_ids, artist__content_category="music")


@registry.register(name="custom")
class CustomRadio(SessionRadio):
    def get_queryset_kwargs(self):
        kwargs = super().get_queryset_kwargs()
        kwargs["user"] = self.session.user
        kwargs["custom_radio"] = self.session.custom_radio
        return kwargs

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        return filters.run(kwargs["custom_radio"].config, candidates=qs)

    def validate_session(self, data, **context):
        data = super().validate_session(data, **context)
        try:
            user = data["user"]
        except KeyError:
            user = context.get("user")
        try:
            assert data["custom_radio"].user == user or data["custom_radio"].is_public
        except KeyError:
            raise serializers.ValidationError("You must provide a custom radio")
        except AssertionError:
            raise serializers.ValidationError("You don't have access to this radio")
        return data


@registry.register(name="custom_multiple")
class CustomMultiple(SessionRadio):
    """
    Receive a vuejs generated config and use it to launch a radio session
    """

    config = serializers.JSONField(required=True)

    def get_config(self, data):
        return data["config"]

    def get_queryset_kwargs(self):
        kwargs = super().get_queryset_kwargs()
        kwargs["config"] = self.session.config
        return kwargs

    def validate_session(self, data, **context):
        data = super().validate_session(data, **context)
        if data.get("config") is None:
            raise serializers.ValidationError(
                "You must provide a configuration for this radio"
            )
        return data

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        return filters.run([kwargs["config"]], candidates=qs)


class RelatedObjectRadio(SessionRadio):
    """Abstract radio related to an object (tag, artist, user...)"""

    related_object_field = serializers.IntegerField(required=True)

    def clean(self, instance):
        super().clean(instance)
        if not instance.related_object:
            raise ValidationError(
                "Cannot start RelatedObjectRadio without related object"
            )
        if not isinstance(instance.related_object, self.model):
            raise ValidationError("Trying to start radio with bad related object")

    def get_related_object(self, pk):
        return self.model.objects.get(pk=pk)


@registry.register(name="tag")
class TagRadio(RelatedObjectRadio):
    model = Tag
    related_object_field = serializers.CharField(required=True)

    def get_related_object(self, name):
        return self.model.objects.get(name=name)

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        query = (
            Q(tagged_items__tag=self.session.related_object)
            | Q(artist__tagged_items__tag=self.session.related_object)
            | Q(album__tagged_items__tag=self.session.related_object)
        )
        return qs.filter(query)

    def get_related_object_id_repr(self, obj):
        return obj.name


def weighted_choice(choices):
    total = sum(w for c, w in choices)
    r = random.uniform(0, total)
    upto = 0
    for c, w in choices:
        if upto + w >= r:
            return c
        upto += w
    assert False, "Shouldn't get here"


class NextNotFound(Exception):
    pass


@registry.register(name="similar")
class SimilarRadio(RelatedObjectRadio):
    model = Track

    def filter_queryset(self, queryset):
        queryset = super().filter_queryset(queryset)
        seeds = list(
            self.session.session_tracks.all()
            .values_list("track_id", flat=True)
            .order_by("-id")[:3]
        ) + [self.session.related_object.pk]
        for seed in seeds:
            try:
                return queryset.filter(pk=self.find_next_id(queryset, seed))
            except NextNotFound:
                continue

        return queryset.none()

    def find_next_id(self, queryset, seed):
        with connection.cursor() as cursor:
            query = """
            SELECT next, count(next) AS c
            FROM (
                SELECT
                    track_id,
                    creation_date,
                    LEAD(track_id) OVER (
                        PARTITION by user_id order by creation_date asc
                    ) AS next
                FROM history_listening
                INNER JOIN users_user ON (users_user.id = user_id)
                WHERE users_user.privacy_level = 'instance' OR users_user.privacy_level = 'everyone' OR user_id = %s
                ORDER BY creation_date ASC
            ) t WHERE track_id = %s AND next != %s GROUP BY next ORDER BY c DESC;
            """
            cursor.execute(query, [self.session.user_id, seed, seed])
            next_candidates = list(cursor.fetchall())

        if not next_candidates:
            raise NextNotFound()

        matching_tracks = list(
            queryset.filter(pk__in=[c[0] for c in next_candidates]).values_list(
                "id", flat=True
            )
        )
        next_candidates = [n for n in next_candidates if n[0] in matching_tracks]
        if not next_candidates:
            raise NextNotFound()
        return random.choice([c[0] for c in next_candidates])


@registry.register(name="artist")
class ArtistRadio(RelatedObjectRadio):
    model = Artist

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        return qs.filter(artist=self.session.related_object)


@registry.register(name="less-listened")
class LessListenedRadio(SessionRadio):
    def clean(self, instance):
        instance.related_object = instance.user
        super().clean(instance)

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        listened = self.session.user.listenings.all().values_list("track", flat=True)
        return (
            qs.filter(artist__content_category="music")
            .exclude(pk__in=listened)
            .order_by("?")
        )


@registry.register(name="less-listened_library")
class LessListenedLibraryRadio(SessionRadio):
    def clean(self, instance):
        instance.related_object = instance.user
        super().clean(instance)

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        listened = self.session.user.listenings.all().values_list("track", flat=True)
        tracks_ids = self.session.user.actor.attributed_tracks.all().values_list(
            "id", flat=True
        )
        query = Q(artist__content_category="music") & Q(pk__in=tracks_ids)
        return qs.filter(query).exclude(pk__in=listened).order_by("?")


@registry.register(name="actor-content")
class ActorContentRadio(RelatedObjectRadio):
    """
    Play content from given actor libraries
    """

    model = federation_models.Actor
    related_object_field = federation_fields.ActorRelatedField(required=True)

    def get_related_object(self, value):
        return value

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        actor_uploads = Upload.objects.filter(
            library__actor=self.session.related_object,
        )
        return qs.filter(pk__in=actor_uploads.values("track"))

    def get_related_object_id_repr(self, obj):
        return obj.full_username


@registry.register(name="library")
class LibraryRadio(RelatedObjectRadio):
    """
    Play content from a given library
    """

    model = Library
    related_object_field = serializers.UUIDField(required=True)

    def get_related_object(self, value):
        return Library.objects.get(uuid=value)

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        actor_uploads = Upload.objects.filter(
            library=self.session.related_object,
        )
        return qs.filter(pk__in=actor_uploads.values("track"))

    def get_related_object_id_repr(self, obj):
        return obj.uuid


@registry.register(name="recently-added")
class RecentlyAdded(SessionRadio):
    def get_queryset(self, **kwargs):
        date = datetime.date.today() - datetime.timedelta(days=30)
        qs = super().get_queryset(**kwargs)
        return qs.filter(
            Q(artist__content_category="music"),
            Q(creation_date__gt=date),
        )


# Use this to experiment on the custom multiple radio with troi
@registry.register(name="troi")
class Troi(SessionRadio):
    """
    Receive a vuejs generated config and use it to launch a troi radio session.
    The config data should follow :
    {"patch": "troi_patch_name", "troi_arg1":"troi_arg_1", "troi_arg2": ...}
    Validation of the config (args) is done by troi during track fetch.
    Funkwhale only checks if the patch is implemented
    """

    config = serializers.JSONField(required=True)

    def append_lb_config(self, data):
        if self.session.user.settings is None:
            logger.warning(
                "No lb_user_name set in user settings. Some troi patches will fail"
            )
            return data
        elif self.session.user.settings.get("lb_user_name") is None:
            logger.warning(
                "No lb_user_name set in user settings. Some troi patches will fail"
            )
        else:
            data["user_name"] = self.session.user.settings["lb_user_name"]

        if self.session.user.settings.get("lb_user_token") is None:
            logger.warning(
                "No lb_user_token set in user settings. Some troi patch will fail"
            )
        else:
            data["user_token"] = self.session.user.settings["lb_user_token"]

        return data

    def get_queryset_kwargs(self):
        kwargs = super().get_queryset_kwargs()
        kwargs["config"] = self.session.config
        return kwargs

    def validate_session(self, data, **context):
        data = super().validate_session(data, **context)
        if data.get("config") is None:
            raise serializers.ValidationError(
                "You must provide a configuration for this radio"
            )
        return data

    def get_queryset(self, **kwargs):
        qs = super().get_queryset(**kwargs)
        config = self.append_lb_config(json.loads(kwargs["config"]))

        return lb_recommendations.run(config, candidates=qs)
