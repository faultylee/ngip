#https://docs.docker.com/compose/django/
FROM python:3.6

ENV PYTHONUNBUFFERED 1

RUN apt-get update && apt-get install -y \
		gcc \
		gettext \
		postgresql-client libpq-dev \
		sqlite3 \
		nano \
		net-tools \
		inotify-tools \
		libldap2-dev \
		libsasl2-dev \
	--no-install-recommends && rm -rf /var/lib/apt/lists/*

# add locales
ENV LANG=en_SG.UTF-8 \
    LANGUAGE=en_SG.UTF-8 \
    LC_CTYPE=en_SG.UTF-8 \
    LC_ALL=en_SG.UTF-8

RUN mkdir /app
WORKDIR /app

COPY requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt

COPY . /app/

RUN mkdir /static
VOLUME /static

EXPOSE 8000
#https://docs.docker.com/compose/django/
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]