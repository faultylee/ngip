from ngip.models import *
from rest_framework import serializers


class PingTokenSerializer(serializers.HyperlinkedModelSerializer):

    class Meta:
        model = PingToken
        fields = ('pk', 'ping', 'token', 'date_last_used')


class PingSerializer(serializers.HyperlinkedModelSerializer):

    class Meta:
        model = Ping
        fields = ('pk', 'account', 'name', 'date_last_received', 'status', 'notified', 'pingtokens')


class AccountSerializer(serializers.HyperlinkedModelSerializer):

    class Meta:
        model = Account
        fields = ('pk', 'name', 'accountpings')


class UserSerializer(serializers.HyperlinkedModelSerializer):

    class Meta:
        model = User
        fields = ('pk', 'email', 'date_joined')

