Add ``client_data`` API app with device registry at ``/api/v1/client-devices/`` (upsert, list, rename, soft-delete).

**OAuth privilege expansion:** ``read:client_data`` and ``write:client_data`` are added to ``COMMON_SCOPES`` and as children of broad ``read`` / ``write``. Existing tokens granted broad ``read`` or ``write`` automatically gain access to client devices, preferences, and playback progress after upgrade. Apps that only requested narrow scopes (e.g. ``read:listenings``) are unaffected.
