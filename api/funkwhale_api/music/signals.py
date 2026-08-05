import django.dispatch
from django.db.models.signals import pre_delete
from django.dispatch import receiver

from .models import ArtistCredit

""" Required args: old_status, new_status, upload """
upload_import_status_updated = django.dispatch.Signal()


@receiver(pre_delete, sender=ArtistCredit)
def remove_artist_credit_relationships(sender, instance, **kwargs):
    instance.albums.all().delete()
    instance.tracks.all().delete()
