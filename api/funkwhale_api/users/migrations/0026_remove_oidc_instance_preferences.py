"""Delete OIDC instance-preference rows (OIDC is env-only now).

Orphaned ``users__oidc_*`` rows in ``dynamic_preferences_globalpreferencemodel``
would still appear in AdminSettings via django-dynamic-preferences' MissingPreference
fallback. Remove them so Instance settings no longer shows OIDC fields.
"""

from django.db import migrations


OIDC_PREF_NAMES = (
    "oidc_enabled",
    "oidc_discovery_url",
    "oidc_client_id",
    "oidc_client_secret",
    "oidc_scopes",
    "oidc_username_claim",
    "oidc_display_name",
    "oidc_auto_create",
)


def delete_oidc_preferences(apps, schema_editor):
    GlobalPreferenceModel = apps.get_model(
        "dynamic_preferences", "GlobalPreferenceModel"
    )
    GlobalPreferenceModel.objects.filter(
        section="users", name__in=OIDC_PREF_NAMES
    ).delete()


def noop_reverse(apps, schema_editor):
    # Preferences are recreated from the registry when registered; OIDC is not.
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0025_auto_20260731_1542"),
        ("dynamic_preferences", "0006_auto_20191001_2236"),
    ]

    operations = [
        migrations.RunPython(delete_oidc_preferences, noop_reverse),
    ]
