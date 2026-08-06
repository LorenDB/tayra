import logging

from funkwhale_api.taskapp import celery

from . import models

logger = logging.getLogger(__name__)


@celery.app.task(name="users.delete_account")
@celery.require_instance(models.User.objects.all(), "user")
def delete_account(user):
    logger.info("Starting deletion of account %s…", user.username)
    user.delete()
    logger.info("Deletion of account done %s!", user.username)
