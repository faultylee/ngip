from django.shortcuts import render
from django.contrib.auth.models import Group
from .models import User, PingToken, Ping
from rest_framework import viewsets
from .serializers import PingSerializer, PingTokenSerializer
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework.reverse import reverse

class PingViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows users to be viewed or edited.
    """
    queryset = Ping.objects.all().order_by('-date_received')
    serializer_class = PingSerializer


class PingTokenViewSet(viewsets.ModelViewSet):
    """
    API endpoint that allows groups to be viewed or edited.
    """
    queryset = PingToken.objects.all().order_by('-date_last_used')
    serializer_class = PingTokenSerializer

@api_view(['GET'])
def api_root(request, format=None):
    return Response({
        'users': reverse('user-list', request=request, format=format),
        'snippets': reverse('snippet-list', request=request, format=format)
    })