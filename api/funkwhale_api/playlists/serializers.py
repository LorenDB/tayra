from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from funkwhale_api.music.models import Track
from funkwhale_api.music.serializers import (
    COVER_WRITE_FIELD,
    CoverField,
    TrackSerializer,
)
from funkwhale_api.users.serializers import UserBasicSerializer

from . import models


class PlaylistTrackSerializer(serializers.ModelSerializer):
    # track = TrackSerializer()
    track = serializers.SerializerMethodField()

    class Meta:
        model = models.PlaylistTrack
        fields = ("track", "index", "creation_date")

    def get_track(self, o):
        track = o._prefetched_track if hasattr(o, "_prefetched_track") else o.track
        return TrackSerializer(track).data


class PlaylistSerializer(serializers.ModelSerializer):
    tracks_count = serializers.SerializerMethodField(read_only=True)
    duration = serializers.SerializerMethodField(read_only=True)
    album_covers = serializers.SerializerMethodField(read_only=True)
    user = UserBasicSerializer(read_only=True)
    is_playable = serializers.SerializerMethodField()
    actor = serializers.SerializerMethodField()
    # Write: attachment UUID. Read representation is set in to_representation.
    cover = COVER_WRITE_FIELD

    class Meta:
        model = models.Playlist
        fields = (
            "id",
            "name",
            "user",
            "modification_date",
            "creation_date",
            "privacy_level",
            "tracks_count",
            "album_covers",
            "duration",
            "is_playable",
            "actor",
            "cover",
        )
        read_only_fields = ["id", "modification_date", "creation_date"]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        cover = instance.attachment_cover
        data["cover"] = (
            CoverField(context=self.context).to_representation(cover) if cover else None
        )
        return data

    def create(self, validated_data):
        cover = validated_data.pop("cover", None)
        return super().create({**validated_data, "attachment_cover": cover})

    def update(self, instance, validated_data):
        if "cover" in validated_data:
            instance.attachment_cover = validated_data.pop("cover")
        return super().update(instance, validated_data)

    def get_actor(self, obj):
        return UserBasicSerializer(obj.user).data

    @extend_schema_field(OpenApiTypes.BOOL)
    def get_is_playable(self, obj):
        try:
            return bool(obj.playable_plts)
        except AttributeError:
            return None

    def get_tracks_count(self, obj) -> int:
        try:
            return obj.tracks_count
        except AttributeError:
            # no annotation?
            return obj.playlist_tracks.count()

    def get_duration(self, obj) -> int:
        try:
            return obj.duration
        except AttributeError:
            # no annotation?
            return 0

    @extend_schema_field({"type": "array", "items": {"type": "string"}})
    def get_album_covers(self, obj):
        try:
            plts = obj.plts_for_cover
        except AttributeError:
            return []

        covers = []
        max_covers = 5
        for plt in plts:
            url = plt.track.album.attachment_cover.download_url_medium_square_crop
            if url in covers:
                continue
            covers.append(url)
            if len(covers) >= max_covers:
                break

        full_urls = []
        for url in covers:
            if "request" in self.context:
                url = self.context["request"].build_absolute_uri(url)
            full_urls.append(url)
        return full_urls


class PlaylistAddManySerializer(serializers.Serializer):
    tracks = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Track.objects.for_nested_serialization()
    )
    allow_duplicates = serializers.BooleanField(required=False)

    class Meta:
        fields = "allow_duplicates"
