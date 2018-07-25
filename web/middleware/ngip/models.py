from django.db import models
import django_extensions.db.models
from django.core.mail import send_mail


class TimeStampedModel(models.Model):
    """ TimeStampedModel
    An abstract base class model that provides self-managed "created" and
    "modified" fields.
    """

    date_created = django_extensions.db.models.CreationDateTimeField("Created On")
    date_modified = django_extensions.db.models.ModificationDateTimeField("Modified On")

    def save(self, **kwargs):
        self.update_modified = kwargs.pop(
            "update_modified", getattr(self, "update_modified", True)
        )
        super(TimeStampedModel, self).save(**kwargs)

    class Meta:
        get_latest_by = "date_modified"
        ordering = ["-date_modified", "-date_created"]
        abstract = True


class Account(TimeStampedModel):
    account_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=255)

    def __str__(self):
        return f"Account: {self.name}"


class PublicUser(TimeStampedModel):
    account = models.ForeignKey(Account, null=True)
    name = models.CharField(max_length=255)
    email = models.EmailField("email address", blank=True)

    def email_user(self, subject, message, from_email=None, **kwargs):
        """
        Sends an email to this User.
        """
        send_mail(subject, message, from_email, [self.email], **kwargs)

    def __str__(self):
        return f"User: {self.name}, Account: {'None' if self.account == None else self.account.name}"


class PublicUserLoginToken:
    public_user = models.ForeignKey(PublicUser)
    token = models.CharField(max_length=255)
    date_create = django_extensions.db.models.CreationDateTimeField("Created On")
    date_login = models.DateTimeField("Login On")

    def __str__(self):
        return f"User: {self.public_user.name}, Created On: {self.date_create}, Login On: {self.date_login}"
