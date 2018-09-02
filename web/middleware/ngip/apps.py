import ngip.tasks
from django.apps import AppConfig
from celery_once.tasks import AlreadyQueued


class NgipConfig(AppConfig):
    name = "ngip"

    def ready(self):
        try:
            # Ignore retrigerring this when started by multiple processes
            ngip.tasks.populatePingTokens.apply_async(countdown=5)
        except AlreadyQueued:
            pass
