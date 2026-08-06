import uuid

import factory

from funkwhale_api.factories import NoUpdateOnCreate, registry
from funkwhale_api.music import factories as music_factories


def get_rss_channel_name():
    return f"rssfeed-{uuid.uuid4()}"


@registry.register
class ChannelFactory(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    uuid = factory.Faker("uuid4")
    owner = factory.SubFactory("funkwhale_api.users.factories.UserFactory")
    preferred_username = factory.Faker("user_name")
    library = factory.SubFactory(
        music_factories.LibraryFactory,
        owner=factory.SelfAttribute("..owner"),
        privacy_level="everyone",
    )
    artist = factory.SubFactory(
        music_factories.ArtistFactory,
    )
    rss_url = factory.Faker("url")
    metadata = factory.LazyAttribute(lambda o: {})

    class Meta:
        model = "audio.Channel"

    class Params:
        external = factory.Trait(
            owner=None,
            preferred_username=factory.LazyFunction(get_rss_channel_name),
            is_external_rss=True,
            library__privacy_level="me",
        )
        local = factory.Trait(
            library__privacy_level="everyone",
        )


@registry.register(name="audio.Subscription")
class SubscriptionFactory(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    uuid = factory.Faker("uuid4")
    approved = True
    channel = factory.SubFactory(ChannelFactory)
    user = factory.SubFactory("funkwhale_api.users.factories.UserFactory")

    class Meta:
        model = "audio.ChannelSubscription"
