from rest_framework import viewsets, generics, status
from rest_framework.response import Response

from .serializers import *


class PingViewSet(viewsets.ModelViewSet):
    queryset = Ping.objects.all().order_by('name')
    serializer_class = PingSerializer


class PingTokenViewSet(viewsets.ModelViewSet):
    queryset = PingToken.objects.all().order_by('-date_last_used')
    serializer_class = PingTokenSerializer


class PingTokenByPing(generics.ListAPIView):
    serializer_class = PingTokenSerializer

    def get_queryset(self):
        return PingToken.objects.filter(ping__pk=self.kwargs['pk']).order_by('-date_last_used')


class AccountViewSet(viewsets.ModelViewSet):
    queryset = Account.objects.all()
    serializer_class = AccountSerializer


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer

