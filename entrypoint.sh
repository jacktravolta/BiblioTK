#!/bin/bash
set -e
rm -rf /app/tmp/pids 2>/dev/null
mkdir -p /app/tmp/pids /tmp/pids
rm -f /app/tmp/pids/server.pid /tmp/server.pid
until pg_isready -h db -p 5432 -U postgres > /dev/null 2>&1; do echo "waiting db..."; sleep 1; done
bundle exec rails db:prepare 2>/dev/null || bundle exec rails db:migrate
bundle exec rails runner tmp/auto_seed.rb
exec "$@"
