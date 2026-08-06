from funkwhale_api.history import serializers
from funkwhale_api.music import serializers as music_serializers
from funkwhale_api.users import serializers as users_serializers


def test_listening_serializer(factories, to_api_date):
    listening = factories["history.Listening"]()

    expected = {
        "id": listening.pk,
        "creation_date": to_api_date(listening.creation_date),
        "track": music_serializers.TrackSerializer(listening.track).data,
        "actor": users_serializers.UserBasicSerializer(listening.user).data,
        "user": users_serializers.UserBasicSerializer(listening.user).data,
    }
    serializer = serializers.ListeningSerializer(listening)

    assert serializer.data == expected
