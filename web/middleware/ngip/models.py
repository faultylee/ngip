from django.contrib.auth.models import User, AbstractUser
from django.db import models
import django_extensions.db.models
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from django.core.mail import send_mail
from django_redis import get_redis_connection
import middleware
import ngip.tasks

class STATUS:
    ACTIVE = "a"
    INACTIVE = "i"
    PAUSED = "p"
    FLAGS = ((ACTIVE, "Active"), (INACTIVE, "Inactive"), (PAUSED, "Paused"))


class PING_STRING_VALUE_COMPARE:
    EQUAL = "eq"
    NOT_EQUAL = "ne"
    BLANK = "z"
    NOT_BLANK = "n"
    FLAGS = (
        (EQUAL, "Equal"),
        (NOT_EQUAL, "Not Equal"),
        (BLANK, "Blank"),
        (NOT_BLANK, "Not Blank"),
    )


class PING_INT_VALUE_COMPARE:
    EQUAL = "eq"
    NOT_EQUAL = "ne"
    BLANK = "z"
    NOT_BLANK = "n"
    GREATER_THAN = "gt"
    GREATER_THAN_OR_EQUAL = "ge"
    LESS_THAN = "lt"
    LESS_THAN_OR_EQUAL = "le"
    FLAGS = (
        (EQUAL, "Equal"),
        (NOT_EQUAL, "Not Equal"),
        (BLANK, "Blank"),
        (NOT_BLANK, "Not Blank"),
        (GREATER_THAN, ">"),
        (GREATER_THAN_OR_EQUAL, ">="),
        (LESS_THAN, "<"),
        (LESS_THAN_OR_EQUAL, "<="),
    )

class AuditModel(models.Model):
    """ AuditModel
    An abstract base class model that provides self-managed "created", "created_by", "modified" and "modified_by"
    fields.
    """

    created_by = models.ForeignKey(
        middleware.settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        related_name="+",
        # GDPR compliance
        on_delete=models.SET_NULL,
    )
    date_created = django_extensions.db.models.CreationDateTimeField("Created On")
    modified_by = models.ForeignKey(
        middleware.settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        related_name="+",
        # GDPR compliance
        on_delete=models.SET_NULL,
    )
    date_modified = django_extensions.db.models.ModificationDateTimeField("Modified On")

    def save(self, **kwargs):
        self.update_modified = kwargs.pop(
            "update_modified", getattr(self, "update_modified", True)
        )
        super(AuditModel, self).save(**kwargs)

    class Meta:
        get_latest_by = "date_modified"
        ordering = ["-date_modified", "-date_created"]
        abstract = True


class Account(AuditModel):
    name = models.CharField(max_length=255)
    status = models.CharField(max_length=1, choices=STATUS.FLAGS)

    def __str__(self):
        return f"Account: {self.name}"


class User(AbstractUser):
    account = models.ForeignKey(Account, null=True)


class UserLoginToken(models.Model):
    user = models.ForeignKey(User)
    token = models.CharField(max_length=255)
    date_create = django_extensions.db.models.CreationDateTimeField("Created On")
    date_login = models.DateTimeField("Login On")

    def __str__(self):
        return (
            f"{self.user}, Created On: {self.date_create}, Login On: {self.date_login}"
        )


class Ping(models.Model):
    account = models.ForeignKey(Account, null=True, related_name='accountpings')
    name = models.CharField(max_length=255)
    date_last_received = models.DateTimeField("Last Received", blank=True, null=True)
    status = models.CharField(max_length=1, choices=STATUS.FLAGS, default=STATUS.ACTIVE)
    notified = models.BooleanField(default=False)

    # TODO: this is causing DRF serialization issue
    # class Meta:
    #     unique_together = ('account', 'name')


class PingToken(AuditModel):
    ping = models.ForeignKey(Ping, related_name='pingtokens')
    token = models.CharField(max_length=255, unique=True)
    date_last_used = models.DateTimeField("Last Used", blank=True, null=True)
    previousToken = None

    def __init__(self, *args, **kwargs):
        super(PingToken, self).__init__(*args, **kwargs)
        self.previousToken = self.token

    def save(self, **kwargs):
        super(PingToken, self).save(**kwargs)
        ngip.tasks.addOrUpdatePingTokens.apply((self.pk, self.token, self.previousToken), countdown=0)
        self.previousToken = self.token

    def delete(self, **kwargs):
        super(PingToken, self).delete(**kwargs)
        ngip.tasks.deletePingTokens.apply((self.token, ), countdown=0)

    def __str__(self):
        return f"{self.ping}, Token: {self.token}, Last Used: {self.date_last_used}"


class PingIntValue(models.Model):
    ping = models.ForeignKey(Ping, on_delete=models.CASCADE)
    key = models.CharField(max_length=255)
    value = models.IntegerField(blank=True, null=True)
    compare = models.CharField(max_length=2, choices=PING_INT_VALUE_COMPARE.FLAGS)

    def __str__(self):
        return f"{self.ping}, Key: {self.key}, Value: {dict(PING_INT_VALUE_COMPARE.FLAGS).get(self.compare)} {self.value}"


class PingStringValue(models.Model):
    ping = models.ForeignKey(Ping, on_delete=models.CASCADE)
    key = models.CharField(max_length=255)
    value = models.CharField(max_length=255, blank=True, null=True)
    compare = models.CharField(max_length=2, choices=PING_STRING_VALUE_COMPARE.FLAGS)

    def __str__(self):
        return f"{self.ping}, Key: {self.key}, Value: {dict(PING_STRING_VALUE_COMPARE.FLAGS).get(self.compare)} {self.value}"


class PingTokenHistory(models.Model):
    token = models.ForeignKey(PingToken, on_delete=models.CASCADE, related_name='pingtokenhistories')
    date_received = models.DateTimeField("Received On")
