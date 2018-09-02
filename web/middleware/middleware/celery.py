from __future__ import absolute_import, unicode_literals

import os
from celery import Celery, bootsteps
from celery.platforms import Signals

# set the default Django settings module for the 'celery' program.
from celery.utils.log import get_task_logger
from django.conf import settings

if not settings.configured:
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'middleware.settings')

app = Celery('middleware')

# Using a string here means the worker don't have to serialize
# the configuration object to child processes.
# - namespace='CELERY' means all celery-related configuration keys
#   should have a `CELERY_` prefix.
app.config_from_object('django.conf:settings', namespace='CELERY')

# Load task modules from all registered Django app configs.
app.autodiscover_tasks()

app.conf.ONCE = {
    'backend': 'celery_once.backends.Redis',
    'settings': {
        'url': settings.CELERY_BROKER_URL,
        'default_timeout': 60 * 5
    }
}


# https://github.com/celery/celery/issues/3076
# https://github.com/MnogoByte/celery-graceful-stop/blob/master/celery_graceful_stop/bootsteps.py
class GracefulWorkerStop(bootsteps.StartStopStep):
    def __init__(self, worker, **kwargs):
        # logging.warn('{0!r} is starting from {1}'.format(worker, __file__))
        pass

    def create(self, worker):
        return self

    def start(self, worker):
        # our step is started together with all other Worker/Consumer
        # bootsteps.
        pass  # not sure in which process this is run.

    def stop(self, worker):
        logger = get_task_logger(__name__)
        logger.info('{0!r} is stopping. Attempting abort of current tasks...'.format(worker))

        # Following code from worker.control.revoke

        task_ids = []
        terminated = set()

        # cleaning all reserved tasks since we are shutting down
        _signals = Signals()
        signum = _signals.signum('TERM')
        for request in [r for r in worker.state.reserved_requests]:
            if request.id not in terminated:
                task_ids.append(request.id)
                terminated.add(request.id)
                logger.info('Terminating %s (%s)', request.id, signum)
                request.terminate(worker.pool, signal=signum)

        # Aborting currently running tasks, and triggering soft timeout exception to allow task to clean up.
        signum = _signals.signum('USR1')
        for request in [r for r in worker.state.active_requests]:
            if request.id not in terminated:
                task_ids.append(request.id)
                terminated.add(request.id)
                logger.info('Terminating %s (%s)', request.id, signum)
                request.terminate(worker.pool, signal=signum)  # triggering SoftTimeoutException in Task

        if terminated:
            terminatedstr = ', '.join(task_ids)
            logger.info('Tasks flagged as revoked: %s', terminatedstr)


app.steps['worker'].add(GracefulWorkerStop)

# Force celery to use our configured log handler

from watchtower import CloudWatchLogHandler
from middleware.settings import LOGGING


def initializeCeleryLog(logger=None, **kwargs):
    handler = CloudWatchLogHandler(
        log_group=LOGGING['handlers']['cwlog-tasks']['log_group'],
        stream_name=LOGGING['handlers']['cwlog-tasks']['stream_name'],
        boto3_session=LOGGING['handlers']['cwlog-tasks']['boto3_session'],
    )
    handler.setLevel(LOGGING['handlers']['cwlog-tasks']['level'])
    # Can't get forammter working properly, getting:
    #   Unrecoverable error: AttributeError("'Formatter' object has no attribute 'level'",)
    # logger.addHandler(logging.Formatter(LOGGING['handlers']['cwlog-tasks']['formatter']))
    return logger


from celery.signals import after_setup_task_logger
after_setup_task_logger.connect(initializeCeleryLog)
from celery.signals import after_setup_logger
after_setup_logger.connect(initializeCeleryLog)
