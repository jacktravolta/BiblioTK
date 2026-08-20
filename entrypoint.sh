#!/bin/bash
set -e
rm -f tmp/pids/server.pid
echo ">> Esperando DB..."
until pg_isready -h db -p 5432 -U postgres > /dev/null 2>&1; do sleep 1; done
echo "db:5432 - accepting connections"
echo ">> Migrando..."
bin/rails db:migrate 2>&1 | tail -20
echo ">> Seed auto..."
bin/rails db:seed 2>&1 | tail -30 || true
exec "$@"
