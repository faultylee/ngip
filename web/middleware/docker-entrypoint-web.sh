#!/bin/bash
#python manage.py test
scripts/wait-for-it.sh $POSTGRES_HOST:$POSTGRES_PORT
python manage.py connectstatic --no-input
python manage.py makemigrations
python manage.py migrate
python manage.py loaddata account
#python manage.py runserver 0.0.0.0:8000
gunicorn middleware.wsgi --workers=2 --bind 0.0.0.0:8000 --timeout 15 --enable-stdio-inheritance
exec "$@"