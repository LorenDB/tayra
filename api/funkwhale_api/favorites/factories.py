import factory

from funkwhale_api.factories import NoUpdateOnCreate, registry
from funkwhale_api.music.factories import TrackFactory
from funkwhale_api.users.factories import UserFactory


@registry.register
class TrackFavorite(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    track = factory.SubFactory(TrackFactory)
    user = factory.SubFactory(UserFactory)

    class Meta:
        model = "favorites.TrackFavorite"
