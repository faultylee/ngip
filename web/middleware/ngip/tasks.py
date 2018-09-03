from __future__ import absolute_import, unicode_literals
import random

from celery.contrib.abortable import AbortableTask
from celery.utils.log import get_task_logger
from django.core.cache import cache
from django.db.models import Q
from django_redis import get_redis_connection
from celery_once import QueueOnce

import middleware
import time

@middleware.celery_app.task(base=QueueOnce, once={'timeout': 60})
def populatePingTokens():
    newCount = 0
    updateCount = 0
    deleteCount = 0

    r = get_redis_connection("default")

    import ngip.models
    for pingToken in ngip.models.PingToken.objects.all():
        newCount += 1
        r.set(f"pingToken_{pingToken.token}", pingToken.pk)

    return f"Ping Token Added: {newCount}, Updated: {updateCount}, Deleted: {deleteCount}"


@middleware.celery_app.task()
def addOrUpdatePingTokens(pk, token, previousToken):
    r = get_redis_connection("default")

    if previousToken:
        r.delete(f"pingToken_{previousToken}")
    r.set(f"pingToken_{token}", pk)

    return f"Ping Token Updated: {previousToken} => {pingToken.token}"


@middleware.celery_app.task()
def deletePingTokens(token):
    r = get_redis_connection("default")

    r.delete(f"pingToken_{token}")

    return f"Ping Token Delete: {pingToken.token}"

@middleware.celery_app.task()
def processPingTokens():
    r = get_redis_connection("default")
    i = 0
    for i in range(0, 100):
        data = r.lpop(f"pingQueue")
        if data:
            token = ngip.models.PingToken.filter(token=data['ping_token'])
            ngip.models.PingTokenHistory.create(
                token = token,
                date_received = time.gmtime(data['ping_token'])
            )
        else:
            break;

    return f"Ping Token Processed : {i}"


