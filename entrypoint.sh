#!/bin/bash
set -e
rm -rf /app/tmp/pids 2>/dev/null
mkdir -p /app/tmp/pids /tmp/pids tmp
rm -f /app/tmp/pids/server.pid /tmp/server.pid
echo ">> Esperando DB..."
until pg_isready -h db -p 5432 -U postgres > /dev/null 2>&1; do sleep 1; done
echo ">> Migrando..."
bundle exec rails db:prepare 2>/dev/null || bundle exec rails db:migrate
echo ">> Seed auto..."
bundle exec rails runner tmp/auto_seed.rb
echo ">> Puma..."
exec bundle exec puma -b tcp://0.0.0.0:3000 --pidfile /tmp/server.pid
