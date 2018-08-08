#!/bin/bash
#python manage.py test
./scripts/wait-for-it.sh db:$POSTGRES_PORT
python manage.py makemigrations
python manage.py migrate
python manage.py loaddata account
python manage.py runserver 0.0.0.0:8000
exec "$@"