#https://docs.docker.com/compose/django/
FROM python:3.6

ENV PYTHONUNBUFFERED 1

RUN apt-get update && apt-get install -y \
		gcc \
		gettext \
		nano \
		net-tools \
		inotify-tools \
		libldap2-dev \
		libsasl2-dev \
	--no-install-recommends && rm -rf /var/lib/apt/lists/*

RUN mkdir /app
WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt

COPY ./redis /app/redis/
COPY fake_lambda.py /app/fake_lambda.py
COPY service.py /app/service.py

ENV FLASK_APP fake_lambda.py

EXPOSE 5000
CMD ["flask", "run", "-h", "0.0.0.0"]