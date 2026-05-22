#!/bin/bash
set -e

POSTGRES_SCHEMA=${POSTGRES_SCHEMA:-mobsf}
GUNICORN_PORT=${GUNICORN_PORT:-7000}

# Create schema if using Postgres
if [ -n "$POSTGRES_USER" ] && [ -n "$POSTGRES_HOST" ]; then
    python3 -c "
import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'mobsf.MobSF.settings')
django.setup()
from django.db import connection
schema = os.getenv('POSTGRES_SCHEMA', 'mobsf')
with connection.cursor() as cursor:
    cursor.execute(f'CREATE SCHEMA IF NOT EXISTS {schema}')
print(f'Schema \"{schema}\" ready.')
"
fi

python3 manage.py makemigrations
python3 manage.py makemigrations StaticAnalyzer

python3 manage.py migrate

set +e
python3 manage.py createsuperuser --noinput --email ""
set -e

python3 manage.py create_roles

exec gunicorn -b 0.0.0.0:${GUNICORN_PORT} "mobsf.MobSF.wsgi:application" \
    --workers=1 \
    --threads=10 \
    --timeout=3600 \
    --worker-tmp-dir=/dev/shm \
    --log-level=critical \
    --log-file=- \
    --access-logfile=- \
    --error-logfile=- \
    --capture-output