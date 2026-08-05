"""Authorization helpers for share-link create and stream access."""

from __future__ import annotations

from django.http import Http404
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import BasePermission

from funkwhale_api.music import models as music_models
from funkwhale_api.playlists import models as playlist_models
from funkwhale_api.users.oauth import permissions as oauth_permissions

from .models import ShareLink


def resolve_active_share(token: str) -> ShareLink | None:
    """Return an active ShareLink for *token*, or None (no existence oracle)."""
    if not token or not isinstance(token, str):
        return None
    # Bound length to avoid pathological query keys / log spam.
    if len(token) > 64 or len(token) < 16:
        return None
    link = (
        ShareLink.objects.filter(token=token)
        .select_related("owner", "owner__actor")
        .first()
    )
    if link is None or not link.is_active:
        return None
    owner = link.owner
    # Disabled accounts must not keep secret links alive.
    if owner is None or not owner.is_active:
        return None
    return link


class ShareOrScopePermission(BasePermission):
    """
    Allow request if a valid ``?share=`` token is present, otherwise fall
    through to normal OAuth ScopePermission.

    Invalid share tokens must not fall through to anonymous library access.
    """

    def has_permission(self, request, view):
        token = request.GET.get("share") or request.query_params.get("share")
        if token:
            link = resolve_active_share(token)
            if link is None:
                return False
            request.share_link = link
            return True
        return oauth_permissions.ScopePermission().has_permission(request, view)


def assert_can_share(user, object_type: str, object_id: int):
    """
    Validate that *user* may create a share for the given object.

    - Album: any authenticated user (album catalog is not privacy-filtered on
      retrieve; stream ACL still uses the sharer's playable uploads).
    - Playlist: only the playlist owner, and the playlist must be visible to them.
    """
    if object_type == ShareLink.OBJECT_ALBUM:
        try:
            return music_models.Album.objects.get(pk=object_id)
        except music_models.Album.DoesNotExist:
            raise Http404

    if object_type == ShareLink.OBJECT_PLAYLIST:
        try:
            playlist = playlist_models.Playlist.objects.get(pk=object_id)
        except playlist_models.Playlist.DoesNotExist:
            raise Http404
        if playlist.user_id != user.pk:
            raise PermissionDenied("Only the playlist owner can create a share link.")
        # Owner can always share their own playlist regardless of privacy_level.
        return playlist

    raise PermissionDenied("Unsupported object type.")
