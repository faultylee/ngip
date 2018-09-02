from rest_framework import viewsets
from .serializers import *


class PingViewSet(viewsets.ModelViewSet):
    queryset = Ping.objects.all().order_by('-date_received')
    serializer_class = PingSerializer


class PingTokenViewSet(viewsets.ModelViewSet):
    queryset = PingToken.objects.all().order_by('-date_last_used')
    serializer_class = PingTokenSerializer


class PingTokenByPing(viewsets.ModelViewSet):
    queryset = PingToken.objects.all().order_by('-date_last_used')
    serializer_class = PingTokenSerializer


class AccountViewSet(viewsets.ModelViewSet):
    queryset = Account.objects.all()
    serializer_class = AccountSerializer


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer

