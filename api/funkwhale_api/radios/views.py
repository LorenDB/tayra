from django.db.models import Q
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from funkwhale_api.common import permissions as common_permissions
from funkwhale_api.music import utils as music_utils
from funkwhale_api.music.serializers import TrackSerializer
from funkwhale_api.users.oauth import permissions as oauth_permissions

from . import filters, filtersets, models, radios_v2, serializers


class RadioViewSet(
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.ListModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = serializers.RadioSerializer
    permission_classes = [
        oauth_permissions.ScopePermission,
        common_permissions.OwnerPermission,
    ]
    filterset_class = filtersets.RadioFilter
    required_scope = "radios"
    owner_field = "user"
    owner_checks = ["write"]
    anonymous_policy = "setting"

    def get_queryset(self):
        queryset = models.Radio.objects.select_related("attachment_cover", "user")
        query = Q(is_public=True)
        if self.request.user.is_authenticated:
            query |= Q(user=self.request.user)
        return queryset.filter(query)

    def perform_create(self, serializer):
        return serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        return serializer.save(user=self.request.user)

    @action(methods=["get"], detail=True, serializer_class=TrackSerializer)
    def tracks(self, request, *args, **kwargs):
        radio = self.get_object()
        tracks = radio.get_candidates().for_nested_serialization()
        actor = music_utils.get_actor_from_request(self.request)
        tracks = tracks.with_playable_uploads(actor)
        tracks = tracks.playable_by(actor)
        page = self.paginate_queryset(tracks)
        if page is not None:
            serializer = TrackSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)

    @action(
        methods=["get"], detail=False, serializer_class=serializers.FilterSerializer
    )
    def filters(self, request, *args, **kwargs):
        serializer = serializers.FilterSerializer(
            filters.registry.exposed_filters, many=True
        )
        return Response(serializer.data)

    @extend_schema(operation_id="validate_radio")
    @action(methods=["post"], detail=False)
    def validate(self, request, *args, **kwargs):
        try:
            f_list = request.data["filters"]
        except KeyError:
            return Response({"error": "You must provide a filters list"}, status=400)
        data = {"filters": []}
        for f in f_list:
            results = filters.test(f)
            if results["candidates"]["sample"]:
                qs = results["candidates"]["sample"].for_nested_serialization()
                results["candidates"]["sample"] = TrackSerializer(qs, many=True).data
            data["filters"].append(results)

        return Response(data)


class RadioSessionViewSet(
    mixins.CreateModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet
):
    serializer_class = serializers.RadioSessionSerializer
    queryset = models.RadioSession.objects.all()
    permission_classes = []

    def get_queryset(self):
        queryset = super().get_queryset()
        if self.request.user.is_authenticated:
            return queryset.filter(
                Q(user=self.request.user)
                | Q(session_key=self.request.session.session_key)
            )

        return queryset.filter(session_key=self.request.session.session_key).exclude(
            session_key=None
        )

    def perform_create(self, serializer):
        if (
            not self.request.user.is_authenticated
            and not self.request.session.session_key
        ):
            self.request.session.create()
        return serializer.save(
            user=self.request.user if self.request.user.is_authenticated else None,
            session_key=self.request.session.session_key,
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["user"] = (
            self.request.user if self.request.user.is_authenticated else None
        )
        return context


class V1_RadioSessionTrackViewSet(mixins.CreateModelMixin, viewsets.GenericViewSet):
    serializer_class = serializers.RadioSessionTrackSerializer
    queryset = models.RadioSessionTrack.objects.all()
    permission_classes = []

    @extend_schema(operation_id="get_next_radio_track")
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        session = serializer.validated_data["session"]
        if not request.user.is_authenticated and not request.session.session_key:
            self.request.session.create()
        if not request.user == session.user or (
            not request.session.session_key == session.session_key
            and not session.session_key
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)

        try:
            session.radio(api_version=1).pick()
        except ValueError:
            return Response(
                "Radio doesn't have more candidates", status=status.HTTP_404_NOT_FOUND
            )
        session_track = session.session_tracks.all().latest("id")
        # dirty override here, since we use a different serializer for creation and detail
        serializer = self.serializer_class(
            instance=session_track, context=self.get_serializer_context()
        )
        headers = self.get_success_headers(serializer.data)
        return Response(
            serializer.data, status=status.HTTP_201_CREATED, headers=headers
        )

    def get_serializer_class(self, *args, **kwargs):
        if self.action == "create":
            return serializers.RadioSessionTrackSerializerCreate
        return super().get_serializer_class(*args, **kwargs)


class V2_RadioSessionViewSet(
    mixins.CreateModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet
):
    """Returns a list of RadioSessions"""

    serializer_class = serializers.RadioSessionSerializer
    queryset = models.RadioSession.objects.all()
    permission_classes = []

    @action(detail=True, serializer_class=serializers.RadioSessionTrackSerializerCreate)
    def tracks(self, request, pk, *args, **kwargs):
        data = {"session": pk}
        data["count"] = (
            request.query_params["count"]
            if "count" in request.query_params.keys()
            else 1
        )
        serializer = serializers.RadioSessionTrackSerializerCreate(data=data)
        serializer.is_valid(raise_exception=True)
        session = serializer.validated_data["session"]

        count = int(data["count"])
        # this is used for test purpose.
        filter_playable = (
            request.query_params["filter_playable"]
            if "filter_playable" in request.query_params.keys()
            else True
        )
        if not request.user.is_authenticated and not request.session.session_key:
            self.request.session.create()

        if not request.user == session.user or (
            not request.session.session_key == session.session_key
            and not session.session_key
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)
        try:
            session.radio(api_version=2).pick_many(
                count, filter_playable=filter_playable
            )
        except ValueError:
            return Response(
                "Radio doesn't have more candidates", status=status.HTTP_404_NOT_FOUND
            )

        # JSON list of track PKs only (M8 — no pickle of model instances).
        track_ids = radios_v2.load_radio_track_ids(session.id)
        batch_ids = track_ids[:count]
        batch = radios_v2.tracks_from_ids(batch_ids)
        serializer = TrackSerializer(batch, many=True)

        remaining_ids = track_ids[count:]
        radios_v2.store_radio_track_ids(session.id, remaining_ids)

        return Response(
            serializer.data,
            status=status.HTTP_201_CREATED,
        )

    def get_queryset(self):
        queryset = super().get_queryset()
        if self.request.user.is_authenticated:
            return queryset.filter(
                Q(user=self.request.user)
                | Q(session_key=self.request.session.session_key)
            )

        return queryset.filter(session_key=self.request.session.session_key).exclude(
            session_key=None
        )

    def perform_create(self, serializer):
        if (
            not self.request.user.is_authenticated
            and not self.request.session.session_key
        ):
            self.request.session.create()
        return serializer.save(
            user=self.request.user if self.request.user.is_authenticated else None,
            session_key=self.request.session.session_key,
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["user"] = (
            self.request.user if self.request.user.is_authenticated else None
        )
        return context
