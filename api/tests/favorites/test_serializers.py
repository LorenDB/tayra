from funkwhale_api.favorites import serializers
from funkwhale_api.music import serializers as music_serializers
from funkwhale_api.users import serializers as users_serializers


def test_track_favorite_serializer(factories, to_api_date):
    favorite = factories["favorites.TrackFavorite"]()

    expected = {
        "id": favorite.pk,
        "creation_date": to_api_date(favorite.creation_date),
        "track": music_serializers.TrackSerializer(favorite.track).data,
        "actor": users_serializers.UserBasicSerializer(favorite.user).data,
        "user": users_serializers.UserBasicSerializer(favorite.user).data,
    }
    serializer = serializers.UserTrackFavoriteSerializer(favorite)

    assert serializer.data == expected
