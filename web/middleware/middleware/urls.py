"""middleware URL Configuration

"""
from django.conf.urls import url, include
from django.contrib import admin
from rest_framework import routers
from ngip import views

# TODO: re-investigate to use https://github.com/alanjds/drf-nested-routers
# ref: https://github.com/Nifled/drf-cheat-sheet

router = routers.DefaultRouter()
router.register(r'account', views.AccountViewSet)
router.register(r'ping', views.PingViewSet)
router.register(r'token', views.PingTokenViewSet)
router.register(r'user', views.UserViewSet)

urlpatterns = [
    url(r'^api/', include(router.urls)),
    url(r"^api/pingtokens/(?P<pk>.+)/$", views.PingTokenByPing.as_view()),
    url(r"^admin/", admin.site.urls),
    url(r'^admin/django-ses/', include('django_ses.urls'))
]
