from rest_framework.renderers import JSONRenderer


class ActivityStreamRenderer(JSONRenderer):
    media_type = "application/activity+json"
