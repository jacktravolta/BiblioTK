#!/bin/bash
set -e
rm -f tmp/pids/server.pid
echo ">> Esperando DB..."
until pg_isready -h db -p 5432 -U postgres; do sleep 1; done
echo ">> Migrando..."
bundle exec rails db:migrate 2>&1 || bundle exec rails db:prepare 2>&1
echo ">> Seed auto..."
SEED_BIG=${SEED_BIG:-false} bundle exec rails runner tmp/auto_seed.rb || true
echo ">> Iniciando web..."
exec bundle exec rails s -b 0.0.0.0 -p 3000
