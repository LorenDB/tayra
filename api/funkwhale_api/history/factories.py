import factory

from funkwhale_api.factories import NoUpdateOnCreate, registry
from funkwhale_api.music import factories
from funkwhale_api.users.factories import UserFactory


@registry.register
class ListeningFactory(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    user = factory.SubFactory(UserFactory)
    track = factory.SubFactory(factories.TrackFactory)
    duration_seconds = None
    source_device = None
    client_session_id = None

    class Meta:
        model = "history.Listening"
