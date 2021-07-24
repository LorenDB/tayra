import pytest
from channels.testing import WebsocketCommunicator
from funkwhale_api.common.consumers import JsonAuthConsumer


@pytest.mark.asyncio
async def test_auth_consumer_requires_valid_user():
    communicator = WebsocketCommunicator(JsonAuthConsumer.as_asgi(), "api/v1/activity")
    communicator.scope["user"] = None
    connected, subprotocol = await communicator.connect()
    assert not connected


@pytest.mark.asyncio
async def test_auth_consumer_requires_user_in_scope():
    communicator = WebsocketCommunicator(JsonAuthConsumer.as_asgi(), "api/v1/activity")
    connected, subprotocol = await communicator.connect()
    assert not connected
