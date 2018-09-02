from django.contrib import admin
from django.contrib.admin import ModelAdmin
from django.contrib.auth.admin import UserAdmin
from ngip import models
from django_ses.views import dashboard


# class AccountPublicUserInline(admin.TabularInline):
#     model = models.User

#admin.site.register_view('django-ses', dashboard, 'Django SES Stats')

@admin.register(models.User)
class PublicUser(UserAdmin):
    pass


PublicUser.list_display = ("username", "email", "account", "is_staff")
PublicUser.fieldsets += ((None, {"fields": ("account",)}),)


@admin.register(models.Account)
class Account(ModelAdmin):

    list_display = ("name", "get_user_count", "get_ping_count")

    readonly_fields = ["created_by", "date_created", "modified_by", "date_modified"]

    inlines = [
        # AccountPublicUserInline
    ]

    def get_user_count(self, obj):
        return models.User.objects.filter(account=obj).count()

    def get_ping_count(self, obj):
        return models.Ping.objects.filter(account=obj).count()

    def save_model(self, request, obj, form, change):
        if not obj.pk:
            # first save
            obj.created_by = request.user
        else:
            obj.modified_by = request.user
        super().save_model(request, obj, form, change)


class PingTokenInline(admin.TabularInline):
    model = models.PingToken
    fields = ["token", "date_last_used"]
    readonly_fields = ["date_last_used"]

    def save_model(self, request, obj, form, change):
        if not obj.pk:
            # first save
            obj.created_by = request.user
        else:
            obj.modified_by = request.user


class PingIntValueInline(admin.TabularInline):
    model = models.PingIntValue


class PingStringValueInline(admin.TabularInline):
    model = models.PingStringValue


@admin.register(models.Ping)
class Ping(ModelAdmin):

    list_display = ["account", "name", "date_last_received", "status", "notified"]

    fields = ["account", "name", "status"]

    inlines = [PingTokenInline, PingIntValueInline, PingStringValueInline]
    pass
