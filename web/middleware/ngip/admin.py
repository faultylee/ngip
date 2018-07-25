from django.contrib import admin
from django.contrib.admin import ModelAdmin
from django.contrib.auth.admin import UserAdmin
from ngip import models


@admin.register(models.Account)
class Account(ModelAdmin):
    pass


@admin.register(models.PublicUser)
class PublicUser(ModelAdmin):
    pass
