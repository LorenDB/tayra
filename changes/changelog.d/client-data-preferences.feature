Add namespaced client preferences API at ``/api/v1/client-preferences/`` (GET with device override resolution; PUT merge/replace). Sensitive keys are rejected server-side; per-scope size limits apply.

**Effective config:** PUT returns only the **written scope** (account *or* device rows; ``resolved: false``). Device-aware effective settings require ``GET ?client_id=&device_uuid=`` (account ∪ device, device wins on key name).

**Inactive devices:** GET of device-scoped prefs is allowed when the device is soft-deleted so historical values remain readable; PUT requires an active (or re-registered) device.
