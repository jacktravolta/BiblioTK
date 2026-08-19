# Bibliotk v2.5 — Motor de calificación O(1) + 50 libros/página

Plataforma de reseñas de libros resiliente a campañas falsas. Home lista **50 libros por página** con query O(1), sin AVG() ni recorrer reseñas.

> **PDF original:** "Solo backend: no se necesita frontend". Todo el front de este repo es iniciativa propia para demo E2E.

## Demo online
**Disponible en:** `http://52.67.100.34:3000/books`
- Home 50 libros O(1) - JSON API también disponible en `/books.json`
- Login user: `user1@test.com / 12345678`
- Login admin: `admin@bibliotk.cl / 123456`

## Requisitos PDF (Backend - Core obligatorio)
- Reseña: stars 1..5, contenido max 1000, 1 por usuario/libro, editable/eliminable
- Promedio: 1 decimal half-up (3.25→3.3), <3 reseñas = "Reseñas Insuficientes", baneados no cuentan
- Home: `SELECT id,title,author,valid_reviews_count,valid_total_stars LIMIT 50 OFFSET` → O(1) con consultas independientes de N libros y N reviews
- Baneo retroactivo: `ban_by!` + `UpdateBookRatingsOnUserBanJob` + `reconcile_valid_ratings!` debe reflejarse en todos los libros
- Concurrencia: validación + unique index + test 200 threads simultáneos
- Tests RSpec: redondeo bordes, umbral 3 reseñas, baneo retroactivo, editar/eliminar, unicidad bajo concurrencia

## Bonus PDF
- Seed que genere un libro con 500.000 reseñas + medición que demuestre que home no se degrada
- Detección anomalías reseñas falsas (propuesta en DECISIONES.md)

## Instalación con Docker (recomendado)
```bash
git clone https://github.com/jacktravolta/BiblioTK.git
cd BiblioTK
docker compose up --build
# http://localhost:3000/books
# http://localhost:3000/books.json
```

**Auto-seed:** 50 libros + 7 users demo. Si `SEED_BIG=true` en docker-compose.yml genera 5000 reviews.

Comandos:
```bash
docker compose exec web bundle exec rspec -fd
docker compose exec web bin/rails runner benchmark_500k.rb
docker compose exec web cat tmp/data_generation_timing.txt
docker compose exec web bin/rails bench # medición batch sin servidor web
```

## Instalación local
```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

## Extras fuera de PDF (Iniciativa propia - Front para demo E2E)

> Estos extras NO eran requerimiento. Se agregaron para poder probar visualmente el motor O(1) y el baneo retroactivo sin usar console.

**Ruta `/books` (extra):**
1. **Banners de Performance (extra):**
   - `Home query O(1) ms`: `Benchmark.realtime { scope.select(:id,:valid_reviews_count,...).limit(50).to_a }`
   - `10x Home ms`: misma query x10 para validar linealidad
   - Lectura de `tmp/data_generation_timing.txt` del seed masivo
2. **Listado (extra):**
   - Paginador 50 libros por página (`limit/offset`) con helper propio `corporate_paginator`
   - Buscador por título/autor case-insensitive (límite 100 chars)
3. **Admin Users `/admin/users` (extra):**
   - Paginador y buscador por nombre/email
   - Banear/desbanear en cascada vía Sidekiq
4. **Detalle libro `/books/:id` (extra):**
   - Comentarios paginados 10 por página
   - Banear/desbanear desde cada reseña si eres admin
   - Filtro automático de baneados para users normales

**Medición sin servidor (para cumplir bonus sin front):**
```bash
bin/rails bench
# o
bin/rails runner "require 'benchmark'; s=Book.order(valid_reviews_count: :desc).limit(50); h=Benchmark.realtime{s.select(:id,:valid_reviews_count,:valid_total_stars).to_a}*1000; puts \"O(1): #{h.round(2)}ms\""
```

## Índices DB (clave para O(1) + concurrencia)

```ruby
# reviews
add_index :reviews, [:user_id, :book_id], unique: true # unicidad 1 review por user/libro + evita race condition 200 threads
add_index :reviews, :book_id
add_index :reviews, [:book_id, :user_id]
add_index :reviews, :user_id

# books - para Home O(1)
add_index :books, :valid_reviews_count
add_index :books, [:valid_reviews_count, :valid_total_stars]

# users
add_index :users, :banned
add_index :users, :email, unique: true
```

- `reviews(user_id, book_id) unique` es el que garantiza el invariante bajo concurrencia real (validación Rails no basta).
- `books(valid_reviews_count)` es el que usa `ORDER BY valid_reviews_count DESC` de la Home sin full scan.

## Estructura clave
- `app/models/book.rb`: `valid_reviews_count`, `valid_total_stars`, `average_rating`, `reconcile_valid_ratings!`
- `app/models/review.rb`: callbacks O(1) `after_create_commit :increment_rating`
- `app/models/user.rb`: `ban_by!`, `unban_by!`
- `app/controllers/books_controller.rb`: Home O(1) + extra banners opcionales
- `app/jobs/update_book_ratings_on_user_ban_job.rb`: recalcula libros afectados
- `benchmark_500k.rb`: `insert_all` + `Benchmark.realtime`

## Autor
**Juan Espinoza Castro** — Product Builder / Fullstack Rails
- juan.espinoza.castro88@gmail.com
- github.com/jacktravolta - Santiago, Chile
