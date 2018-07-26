#!/bin/bash -e

rm db.sqlite3
rm ngip/migrations/00*.py
python manage.py makemigrations
python manage.py migrate
python manage.py loaddata account
