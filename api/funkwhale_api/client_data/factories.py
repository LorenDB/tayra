import factory

from funkwhale_api.factories import NoUpdateOnCreate, registry
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
