from flask import Flask, request
import service
import json

app = Flask(__name__)


@app.route('/')
def hello_world():
    return 'Hello, World!'


@app.route("/ping/<string:ping_token>")
def ping(ping_token):
    return json.dumps(service.handler({'pathParameters': {'pingToken': ping_token}}, None))
