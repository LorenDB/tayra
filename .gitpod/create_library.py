from funkwhale_api.music.models import Library
from django.contrib.auth import get_user_model

actor = get_user_model().objects.get(username='gitpod').actor

try:
    library = Library.objects.get(actor=actor)
except:
    #  Create library
    library = Library()
    library.actor = actor
    library.description = 'Libre music to build a starter catalog for your instance'
    library.name = 'funkwhale/catalog'
    library.privacy_level = 'everyone'
    library.save()

print(str(library.uuid))