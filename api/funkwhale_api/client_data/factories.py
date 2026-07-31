import factory

from funkwhale_api.factories import NoUpdateOnCreate, registry
from funkwhale_api.music.factories import TrackFactory
from funkwhale_api.users.factories import UserFactory


@registry.register
class ClientDeviceFactory(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    uuid = factory.Faker("uuid4")
    user = factory.SubFactory(UserFactory)
    name = factory.Faker("word")
    client_id = "tayra"
    client_version = "1.0.0"
    is_active = True

    class Meta:
        model = "client_data.ClientDevice"


@registry.register
class ClientPreferenceFactory(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    user = factory.SubFactory(UserFactory)
    client_id = "tayra"
    device = None
    key = factory.Sequence(lambda n: f"pref_key_{n}")
    value = factory.LazyFunction(lambda: True)

    class Meta:
        model = "client_data.ClientPreference"

class PlaybackProgressFactory(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    user = factory.SubFactory(UserFactory)
    track = factory.SubFactory(TrackFactory)
    position_ms = 0
    duration_ms = None
    completed = False
    channel_uuid = None

    class Meta:
        model = "client_data.PlaybackProgress"
