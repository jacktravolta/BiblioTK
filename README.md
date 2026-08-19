# Bibliotk v2.5 — Motor de calificación O(1) + 50 libros/página PDF

Plataforma de reseñas de libros resiliente a campañas falsas. Home lista **50 libros por página** con query O(1), sin AVG() ni recorrer reseñas.

## Demo online
**Disponible en:** `http://52.67.100.34:3000/books` y `http://52.67.100.34:3000/books`
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

## Instalación
```bash
bundle install
bin/rails db:create db:migrate
bin/rails db:seed # crea admin@test.com / 123456 y 50 libros base
```

## Usuarios demo
- Admin: `admin@bibliotk.cl / 123456` o `admin@test.com / 123456`
- Users: `user1@test.com`..`user5@test.com / 12345678`
- Tester: `tester@bibliotk.cl / 123456`

## Probar todos los puntos PDF
```bash
# Fix limpio + todos los tests
bin/rails runner /tmp/fix_final.rb

# Bonus + timing (genera tmp/data_generation_timing.txt)
bin/rails runner benchmark_500k.rb
cat tmp/data_generation_timing.txt

# RSpec
bundle exec rspec -fd

# Server
bin/rails server -b 0.0.0.0 -p 3000
# http://localhost:3000/books -> 50 libros + banners timing
# Login admin -> cada reseña tiene botón 🚫 Banear desde front
```

## Estructura clave
- `app/models/book.rb`: `valid_reviews_count`, `valid_total_stars`, `average_rating`, `increment/decrement/sync/reconcile_valid_ratings!`
- `app/models/review.rb`: callbacks O(1) `after_create_commit :add_to_rating`
- `app/models/user.rb`: `ban_by!`, `unban_by!`, `can_review?`
- `app/controllers/books_controller.rb`: `@per_page = 50` fijo, lee `tmp/data_generation_timing.txt`
- `benchmark_500k.rb`: envuelve en `Benchmark.realtime total_time` y guarda timing
- `DECISIONES.md`: trade-offs, qué se deja fuera, qué haría con 1 semana más

## Paginadores
- Home: 50 por página `?page=`
- Libro: reviews 20 por página `?reviews_page=`
- Users: 20 por página, User show: 10 por página
- Helper `corporate_paginator` sin gemas, preserva query params

## Timing visible en front
3 banners en `/books`:
- Home query O(1) ms
- Benchmark 10x Home ms
- Generación Data (de `tmp/data_generation_timing.txt`)

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
- **Stack:** Rails 7 + PostgreSQL (atomización ACID, redundancia, soporte pgvector para búsqueda semántica futura) + Sidekiq + Tailwind

> Este proyecto incluye 2 extras fuera de scope (IA Ban retroactivo + Front corporativo) bajo visión de producto: el módulo IA no es determinante para la ejecución, es una capa desacoplada de moderación. El front se desarrolló para pruebas E2E reales.