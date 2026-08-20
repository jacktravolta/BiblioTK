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

## Configuración Base de Datos

**Dónde se configura:**
- `config/database.yml` - Rails usa `ENV['DATABASE_URL']` si existe, si no usa host `db` (servicio Docker)
- `docker-compose.yml` - Define Postgres 15 + credenciales + volumen persistente
- `.env` (opcional) - No requerido en Docker, usa defaults

```yaml
# docker-compose.yml (resumen)
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_USER: bibliotk
      POSTGRES_PASSWORD: bibliotk123
      POSTGRES_DB: bibliotk_development
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  web:
    environment:
      DATABASE_URL: postgres://bibliotk:bibliotk123@db:5432/bibliotk_development
      REDIS_URL: redis://redis:6379/0
      RAILS_ENV: development
      SEED_BIG: "false" # true = genera 5000 reviews en primer arranque
```

```yaml
# config/database.yml
development:
  url: <%= ENV['DATABASE_URL'] || 'postgres://bibliotk:bibliotk123@localhost:5432/bibliotk_development' %>
  pool: 10 # importante para test 200 threads

test:
  url: <%= ENV['DATABASE_URL'] || 'postgres://bibliotk:bibliotk123@localhost:5432/bibliotk_test' %>
```

**Cómo se inicializa:**
- `entrypoint.sh` espera a postgres (`pg_isready -h db`) + `bin/rails db:prepare` (create + migrate si no existe) + corre `tmp/auto_seed.rb` idempotente
- Si borras volumen: `docker compose down -v && docker compose up --build` → re-seed automático 50 libros + 7 users

**Local sin Docker:**
```bash
# postgres local debe estar corriendo
# config/database.yml usa localhost por defecto si no hay DATABASE_URL
createdb bibliotk_development
bin/rails db:migrate db:seed
```

**Índices clave (ver sección Índices DB abajo):**
- `reviews(user_id, book_id) unique` → unicidad + concurrencia
- `books(valid_reviews_count)` → Home O(1) sin sort en memoria

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

## Pruebas manuales por consola (sin front) - Core PDF

**1. Probar O(1) - Home 50 libros sin AVG():**
```bash
# Local
bin/rails console

# Docker
docker compose exec web bin/rails console
```
```ruby
# Console
book = Book.create!(title: "Test123", author: "Test")

# Crear 3 reviews válidas
3.times do |i|
  user = User.create!(
    name: "Test #{i}",
    email: "t#{i}_#{Time.now.to_i}#{i}@t.cl",
    password: "12345678"
  )
  Review.create!(book: book, user: user, stars: 5)
end

book.reload.average_rating # => 5.0

# Medir Home O(1)
require 'benchmark'
time = Benchmark.realtime { 
  Book.order(valid_reviews_count: :desc).limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).to_a 
} * 1000
puts "Home O(1): #{time.round(2)}ms"

# Con 500k reviews sigue igual
load 'benchmark_500k.rb' # genera libro con 500k
time2 = Benchmark.realtime { 
  Book.order(valid_reviews_count: :desc).limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).to_a 
} * 1000
puts "Con 500k: #{time2.round(2)}ms - debe ser similar a #{time.round(2)}ms"
```


**2. Probar baneo retroactivo:**
```ruby
# console
admin = User.find_by(email: "admin@bibliotk.cl")
user = User.find_by(email: "user1@test.com")
book = Book.first

# Usuario reseña
review = Review.create!(book: book, user: user, stars: 5, content: "Excelente")
book.reload.valid_reviews_count # => 1

# Banear - debe bajar contador
user.ban_by!(admin)
book.reload.valid_reviews_count # => 0
book.average_rating # => "Reseñas Insuficientes"

# Desbanear - debe subir
user.unban_by!(admin)
book.reload.valid_reviews_count # => 1
```

**3. Probar umbral 3 reseñas y redondeo half-up:**
```ruby
book = Book.create!(title: "Borde", author: "Test")
# <3 reviews
2.times { |i| Review.create!(book: book, user: User.create!(email: "b#{i}@b.cl", password: "12345678"), stars: 5) }
book.average_rating # => "Reseñas Insuficientes"

# 3ra review
Review.create!(book: book, user: User.create!(email: "b3@b.cl", password: "12345678"), stars: 4)
book.reload.average_rating # => 4.7 ( (5+5+4)/3 = 4.666 -> 4.7 half-up)

# Borde 3.25 -> 3.3
book2 = Book.create!(title: "Borde2", author: "Test")
[3,3,3,4].each_with_index { |s,i| Review.create!(book: book2, user: User.create!(email: "c#{i}@c.cl", password: "12345678"), stars: s) }
book2.average_rating # 3.25 -> 3.3
```

**4. Probar unicidad y concurrencia (200 threads):**
```bash
# RSpec cubre esto
bundle exec rspec spec/models/review_concurrency_spec.rb -fd
# o manual:
bin/rails runner "
book = Book.first
user = User.first
threads = 20.times.map { Thread.new { begin; Review.create!(book: book, user: user, stars: 5); rescue => e; puts e.message; end } }
threads.each(&:join)
puts \"Total reviews user/book: #{Review.where(book: book, user: user).count} debe ser 1\"
"
```

**5. Probar editar/eliminar:**
```ruby
review = Review.first
review.update!(stars: 1, content: "Cambié opinión")
review.book.reload.average_rating # debe recalcular

review.destroy!
review.book.reload.valid_reviews_count # debe decrementar
```

**6. Tests completos RSpec (lo que pide PDF):**
```bash
# Docker
docker compose exec web bundle exec rspec -fd
docker compose exec web bundle exec rspec spec/models/book_spec.rb -fd # redondeo bordes, umbral 3
docker compose exec web bundle exec rspec spec/models/review_spec.rb -fd # ciclo editar/eliminar, baneo retroactivo
docker compose exec web bundle exec rspec spec/models/review_concurrency_spec.rb -fd # unicidad 200 threads

# Local
bundle exec rspec -fd
```

**7. Probar JSON API (sin front, cumple PDF "solo backend"):**
```bash
curl http://localhost:3000/books.json | jq '.[0]'
curl http://localhost:3000/books/1.json | jq '.average_rating'
curl -X POST http://localhost:3000/books/1/reviews -H "Content-Type: application/json" -d '{"review":{"stars":5,"content":"Test"}}'
```

**8. Bonus 500k + medición:**
```bash
bin/rails runner benchmark_500k.rb
cat tmp/data_generation_timing.txt
# Debe mostrar: Home 50 libros O(1) sigue en <50ms con 500k reviews en catálogo
bin/rails bench # medición batch sin servidor web
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
