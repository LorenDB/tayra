import uuid

from django.db import transaction

from funkwhale_api.common import mutations, utils

from . import models, tasks


@mutations.registry.connect("delete_account", models.User)
class DeleteAccountMutationSerializer(mutations.MutationSerializer):
    @transaction.atomic
    def apply(self, obj, validated_data):
        if not obj.is_active:
            raise mutations.serializers.ValidationError("Cannot delete this account")

        # delete oauth apps / reset all passwords immediately
        obj.set_unusable_password()
        # force logout
        obj.secret_key = uuid.uuid4()
        obj.users_grant.all().delete()
        obj.users_accesstoken.all().delete()
        obj.users_refreshtoken.all().delete()
        obj.save()

        # since the deletion of related objects can take a long time
        # we do that in a separate task
        utils.on_commit(tasks.delete_account.delay, user_id=obj.id)

    def get_previous_state(self, obj, validated_data):
        """
        We store usernames and ids for auditability purposes
        """
        return {
            "user": {"username": obj.username, "id": obj.pk},
        }
