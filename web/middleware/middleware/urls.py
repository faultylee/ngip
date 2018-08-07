"""middleware URL Configuration

"""
from django.conf.urls import url, include
from django.contrib import admin
from rest_framework import routers
from ngip import views

router = routers.DefaultRouter()
router.register(r'ping', views.PingViewSet)
router.register(r'ping/token', views.PingTokenViewSet)

urlpatterns = [
    url(r'^', include(router.urls)),
    url(r"^admin/", admin.site.urls)
]
