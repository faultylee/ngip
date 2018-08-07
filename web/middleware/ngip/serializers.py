from ngip.models import Ping, PingToken
from rest_framework import serializers


class PingSerializer(serializers.HyperlinkedModelSerializer):

    account = serializers.StringRelatedField()
    tokens = serializers.StringRelatedField()

    class Meta:
        model = Ping
        fields = ('account', 'name', 'date_received', 'status', 'notified', 'tokens')


class PingTokenSerializer(serializers.HyperlinkedModelSerializer):
    class Meta:
        model = PingToken
        fields = ('ping', 'token', 'date_last_used')