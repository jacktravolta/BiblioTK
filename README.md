# Bibliotk v2.5 — Motor de calificación O(1) + 50 libros/página PDF

Plataforma de reseñas de libros resiliente a campañas falsas. Home lista **50 libros por página** con query O(1), sin AVG() ni recorrer reseñas.

## Demo online
**Disponible en:** `http://52.67.100.34:3000/books`
- Home 50 libros O(1) + 3 banners con timing de generación
- Login user: `user1@test.com / 12345678`
- Login admin: `admin@bibliotk.cl / 123456` → botón 🚫 Banear desde front en cada reseña
- Paginadores: `/books?page=2`, `/books/1?reviews_page=2`, `/users?page=2`

## Requisitos PDF homologados
- Reseña: stars 1..5, contenido max 1000, 1 por usuario/libro, editable/eliminable
- Promedio: 1 decimal half-up (3.25→3.3), <3 reseñas = "Reseñas Insuficientes", baneados no cuentan
- Home: `SELECT id,title,author,valid_reviews_count,valid_total_stars LIMIT 50 OFFSET` → O(1)
- Baneo retroactivo: `ban_by!` + `UpdateBookRatingsOnUserBanJob` + `reconcile_valid_ratings!`
- Concurrencia: validación + unique index + test 20 threads (200 en PDF)
- Bonus 500k: `benchmark_500k.rb` genera libro con 500k reseñas y mide Home

## Instalación con Docker (recomendado)

**Auto-seed automático:** Al hacer `docker compose up --build` se crean 50 libros + admins + 5 users demo. Si `SEED_BIG=true`, genera 5000 reviews automáticamente en el primer arranque.

```bash
git clone https://github.com/jacktravolta/BiblioTK.git
cd BiblioTK

# Build + seed automático (50 libros + admins)
docker compose up --build

# Logs esperados:
# >> Seed 50 libros + usuarios demo...
# >> DB lista: 50 libros, 7 users, 0 reviews
# * Listening on http://0.0.0.0:3000

# Abrir
# http://localhost:3000/books
```

**Con benchmark 5000 reviews (30-60s primera vez):**

El `docker-compose.yml` ya viene con:
```yaml
environment:
  SEED_BIG: "true"
```

Si quieres desactivarlo:
```bash
# Edita docker-compose.yml y pon SEED_BIG: "false"
```

**Comandos útiles Docker:**
```bash
docker compose down              # apaga
docker compose down -v           # borra DB y vuelve a seedear desde cero
docker compose logs -f web       # ver logs
docker compose exec web bin/rails console
docker compose exec web bundle exec rspec -fd
docker compose exec web bin/rails runner benchmark_500k.rb
docker compose exec web cat tmp/data_generation_timing.txt
```

**Servicios:**
- `web:3000` Rails 7 + `entrypoint.sh` (espera postgres + db:prepare + runner tmp/auto_seed.rb)
- `db:5432` Postgres 15
- `redis:6379` Redis
- `sidekiq` Jobs de baneo retroactivo

**Estructura Docker:**
- `Dockerfile`: ruby:3.2 + build deps
- `docker-compose.yml`: web/db/redis/sidekiq
- `entrypoint.sh`: idempotente, no requiere seed manual
- `tmp/auto_seed.rb`: seed 50 libros + users + benchmark si SEED_BIG
- `tmp/data_generation_timing.txt`: timing visible en banners del home

## Instalación local (sin Docker)
```bash
bundle install
bin/rails db:create db:migrate
bin/rails db:seed # crea admin@test.com / 123456 y 50 libros base
bin/rails server -b 0.0.0.0 -p 3000
```

## Usuarios demo
- Admin: `admin@bibliotk.cl / 123456` o `admin@test.com / 123456`
- Users: `user1@test.com`..`user5@test.com / 12345678`
- Tester: `tester@bibliotk.cl / 123456`

## Probar todos los puntos PDF
```bash
# Docker
docker compose exec web bin/rails runner benchmark_500k.rb
docker compose exec web bundle exec rspec -fd

# Local
bin/rails runner benchmark_500k.rb
cat tmp/data_generation_timing.txt
bundle exec rspec -fd
```

## Estructura clave
- `app/models/book.rb`: `valid_reviews_count`, `valid_total_stars`, `average_rating`, `increment/decrement/sync/reconcile_valid_ratings!`
- `app/models/review.rb`: callbacks O(1) `after_create_commit :add_to_rating`
- `app/models/user.rb`: `ban_by!`, `unban_by!`, `can_review?`
- `app/controllers/books_controller.rb`: `@per_page = 50` fijo, lee `tmp/data_generation_timing.txt`
- `app/jobs/update_book_ratings_on_user_ban_job.rb`: recalcula libros afectados por baneo
- `entrypoint.sh`: espera postgres + `db:prepare` + `tmp/auto_seed.rb` idempotente
- `benchmark_500k.rb`: envuelve en `Benchmark.realtime total_time` y guarda timing con `insert_all`
- `DECISIONES.md`: trade-offs

## Paginadores
- Home: 50 por página `?page=`
- Libro: reviews 20 por página `?reviews_page=`
- Users: 20 por página, User show: 10 por página
- Helper `corporate_paginator` sin gemas

## Timing visible en front
3 banners en `/books`:
- Home query O(1) ms
- Benchmark 10x Home ms

## Entregables
1. Código + instrucciones (este README)
2. `DECISIONES.md` breve
3. Bonus seed + medición

## Autor

**Juan Espinoza Castro** — Product Builder / Fullstack Ruby on Rails

- **Email:** juan.espinoza.castro88@gmail.com
- **GitHub:** [jacktravolta](https://github.com/jacktravolta)
- **Ubicación:** Santiago, Chile
- **Repo:** https://github.com/jacktravolta/BiblioTK
- **Demo:** http://52.67.100.34:3000/books
- **Stack:** Rails 7 + PostgreSQL (atomización ACID, redundancia, soporte pgvector para búsqueda semántica futura) + Redis/Sidekiq + Docker + Tailwind

> Este proyecto incluye 2 extras fuera de scope (IA Ban retroactivo + Front corporativo) bajo visión de producto: el módulo IA no es determinante para la ejecución, es una capa desacoplada de moderación. El front se desarrolló para pruebas E2E reales.
