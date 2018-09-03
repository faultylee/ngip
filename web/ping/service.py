# -*- coding: utf-8 -*-

import os
import json
import redis
import time


def handler(event, context):

    response = {
        "statusCode": 503,
        "body": "missing token"
    }
    try:
        path_params = event.get('pathParameters')
        if path_params:
            if 'REDIS_USE_SSL' in os.environ and os.environ['REDIS_USE_SSL'] == "1":
                r = redis.StrictRedis(host=os.environ['REDIS_HOST'],
                                      password=os.environ['REDIS_PASSWORD'],
                                      db=os.environ['REDIS_DB'],
                                      ssl=True,
                                      ssl_ca_certs=os.environ['REDIS_SSL_CA_CERTS'],
                                      ssl_cert_reqs=os.environ['REDIS_SSL_CERT_REQ'],
                                      ssl_certfile=os.environ['REDIS_SSL_CERTFILE'],
                                      ssl_keyfile=os.environ['REDIS_SSL_KEYFILE']
                                      )
            else:
                r = redis.StrictRedis(host=os.environ['REDIS_HOST'], db=os.environ['REDIS_DB'])
            ping_token = path_params.get('pingToken')
            if ping_token:
                if r.get(f"pingToken_{ping_token}"):
                    timestamp = int(time.time())
                    r.rpush("pingQueue", {"timestamp": timestamp, "ping_token": ping_token})
                    # r.publish(f"ping_queue", {"timestamp": timestamp, "ping_token": ping_token})
                    # r.set(ping_token, timestamp)
                    response = {
                        "statusCode": 200,
                        'headers': {'Content-Type': 'application/json'},
                        "body": json.dumps({
                            "ping_token": ping_token,
                            "timestamp": timestamp,
                            "status": "OK"
                        })
                    }
                else:
                    response = {
                        "statusCode": 403,
                        "body": "invalid token"
                    }
        # missing token, but taken care by API Gateway
    except Exception as e:
        response = {
            "statusCode": 503,
            "body": str(e)
        }

    return response
