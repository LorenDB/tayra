from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
from django.conf.urls import url
from django.core.asgi import get_asgi_application

from funkwhale_api.instance import consumers

application = ProtocolTypeRouter(
    {
        # Empty for now (http->django views is added by default)
        "websocket": AuthMiddlewareStack(
            URLRouter(
                [url("^api/v1/activity$", consumers.InstanceActivityConsumer.as_asgi())]
            )
        ),
        "http": get_asgi_application(),
    }
)
