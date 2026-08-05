import factory

from funkwhale_api.factories import NoUpdateOnCreate, registry
from funkwhale_api.users.factories import UserFactory

from . import models


@registry.register
class ShareLinkFactory(NoUpdateOnCreate, factory.django.DjangoModelFactory):
    owner = factory.SubFactory(UserFactory)
    object_type = models.ShareLink.OBJECT_ALBUM
    object_id = factory.Sequence(lambda n: n + 1)
    label = ""

    class Meta:
        model = "shares.ShareLink"
