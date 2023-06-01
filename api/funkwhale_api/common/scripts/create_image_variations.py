"""
Compute different sizes of image used for Album covers and User avatars
"""

from versatileimagefield.image_warmer import VersatileImageFieldWarmer

from funkwhale_api.common.models import Attachment

MODELS = [
    (Attachment, "file", "attachment_square"),
]


def main(command, **kwargs):
    for model, attribute, key_set in MODELS:
        qs = model.objects.exclude(**{f"{attribute}__isnull": True})
        qs = qs.exclude(**{attribute: ""})
        warmer = VersatileImageFieldWarmer(
            instance_or_queryset=qs,
            rendition_key_set=key_set,
            image_attr=attribute,
            verbose=True,
        )
        command.stdout.write(f"Creating images for {model.__name__} / {attribute}")
        num_created, failed_to_create = warmer.warm()
        command.stdout.write(
            f"  {num_created} created, {len(failed_to_create)} in error"
        )
