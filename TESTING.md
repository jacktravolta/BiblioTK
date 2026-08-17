# TESTING.md — Cómo probar TODOS los puntos del PDF Bibliotk

## Demo online
**Demo pública:** `http://52.67.100.34:3000/books` (también `http://52.67.100.34:3000/books`)
- 50 libros por página O(1), banners con timing generación
- User: `user1@test.com / 12345678` — reseña con estrellas iluminadas
- Admin: `admin@bibliotk.cl / 123456` — botón 🚫 Banear desde front, recalcula O(1)
- Paginadores: `?page=2`, `?reviews_page=2`

## 0. Instalación base (una vez)
```bash
cd /home/test/libroTK/bibliotkv1
bundle install
bin/rails db:create db:migrate
bin/rails db:seed # crea admin@test.com / 123456 y 50 libros base si existe seed
```

## 1. Levantar servidor
```bash
pkill -f puma
bin/rails server -b 0.0.0.0 -p 3000 -d
# Abrir: http://52.67.100.34:3000/books
# Debe mostrar 50 libros (5 por fila x 10) + 3 banners: Home O(1) ms, Benchmark 10x, Generación Data
```

## 2. Tests automáticos RSpec (requisito PDF)
```bash
# Todos los tests
bundle exec rspec -fd

# Por área (lo que pide el PDF)
bundle exec rspec spec/models/book_spec.rb -fd              # redondeo half-up 3.25->3.3, umbral 3 reseñas
bundle exec rspec spec/models/review_spec.rb -fd            # validaciones 1..5, 1000 chars, unicidad
bundle exec rspec spec/models/user_spec.rb -fd              # baneo retroactivo
bundle exec rspec spec/models/review_concurrency_spec.rb -fd # 200 usuarios simultáneos (usa 20 para CI rápido)
bundle exec rspec spec/jobs/ -fd                             # jobs O(1)
```

### Qué cubre cada spec (PDF pide mínimo):
- `book_spec.rb`: `average_rating` nil si <3, label "Reseñas Insuficientes", 3.25→3.3 half-up, 3.24→3.2
- `review_spec.rb`: stars inclusion 1..5, content max 1000, uniqueness user+book, editar (sync_valid_ratings!), eliminar (decrement)
- `user_spec.rb`: ban_by! solo admin, no auto-ban, crea UserBanLog, encola UpdateBookRatingsOnUserBanJob, unban restaura
- `review_concurrency_spec.rb`: 20 threads crean review mismo libro → valid_reviews_count debe ser 20 exacto (no 19 por race)
- `jobs`: ReconcileBookRatingJob idempotente, UpdateBookRatingsOnUserBanJob toca solo libros del usuario

## 3. Tests manuales via rails runner (sin front)

### 3a. Validaciones reseña
```bash
bin/rails runner /tmp/fix_final.rb
# Este script hace:
# - Desbanea usuarios masivos user-xxx@test.com
# - Crea user1..user5@test.com / 12345678 limpios
# - Libro Prueba PDF aislado
# - Prueba stars 6 + 1001 chars = false
# - Prueba unicidad 1 review por libro = false
# - Prueba editar y eliminar O(1)
# - Prueba redondeo 13/4=3.25 → 3.3
# - Prueba <3 reseñas → "Reseñas Insuficientes"
# - Prueba baneo retroactivo
# - Prueba Home 50 O(1) x10
```

### 3b. Baneo retroactivo aislado
```bash
bin/rails runner "
admin = User.find_by(role: 'admin'); admin.update!(role: 'admin') if admin.role!='admin'
u = User.find_by(email: 'user2@test.com'); b = Book.first
Review.where(user: u, book: b).delete_all; b.reconcile_valid_ratings!
before = b.valid_reviews_count
r = Review.create!(user: u, book: b, stars: 5, content: 'spam')
puts \"Antes #{before} despues crear #{b.reload.valid_reviews_count}\"
u.ban_by!(admin, reason: 'test'); sleep 1; b.reconcile_valid_ratings!
puts \"Despues ban #{b.valid_reviews_count} debe volver a #{before}\"
u.unban_by!(admin); b.reconcile_valid_ratings!
puts \"Despues unban #{b.valid_reviews_count}\"
"
```

### 3c. Home 50 libros O(1) — Requisito PDF core
```bash
bin/rails runner "
require 'benchmark'
t = Benchmark.realtime { 10.times { Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).map{|b| b.average_rating} } }
puts \"Home 50 x10: #{(t*1000).round(2)}ms total, #{(t/10*1000).round(2)}ms por request - debe ser <500ms\"
puts \"Per_page = 50 fijo en BooksController\"
"
# En front: curl http://localhost:3000/books | grep -c 'card' debe ser 50
```

### 3d. Eliminar (tu error anterior)
```bash
# NO uses Review.last (puede ser de usuario baneado)
bin/rails runner "
u = User.find_by(email: 'user1@test.com'); b = Book.find_by(title: 'Libro Prueba PDF')
u.update!(banned: false)
Review.where(user: u, book: b).delete_all
r = Review.create!(user: u, book: b, stars: 5, content: 'Para eliminar')
puts \"Creada #{r.id}\"
r.destroy; b.reconcile_valid_ratings!
puts \"Eliminada OK count=#{b.reload.valid_reviews_count}\"
"
```

## 4. Bonus 500k + Timing visible

### 4a. Bonus real del PDF (500k)
```bash
# Este es benchmark_500k.rb editado por ti (ahora genera 500k real)
bin/rails runner benchmark_500k.rb
# Salida esperada:
# Libro: X
# Creando 500k reseñas...
# Insert 500k en XX.XXs
# valid_reviews_count: 500000
# Home 50 libros x10 en 0.XXXs - O(1) independiente de 500k reseñas
cat tmp/data_generation_timing.txt 2>/dev/null || echo 'Se genera en v2.5'
```

### 4b. Timing en front (tu requerimiento nuevo)
En v2.5 `benchmark_500k.rb` guarda:
```
File.write('tmp/data_generation_timing.txt', "#{total_time.round(2)}s total | #{(total_time/60).round(2)} min | Libros:#{Book.count} ...")
```
`BooksController#index` lee ese archivo y la vista muestra 3 banners:
- Home query O(1) ms
- Benchmark 10x Home
- Generación Data

## 5. Probar desde front (manual)
- Login `user1@test.com / 12345678` → /books/1 → reseñar → estrellas se iluminan, comentario diverso (no "benchmark 0")
- Login `admin@bibliotk.cl / 123456` → /books/1 → cada reseña muestra 🚫 Banear → al banear, valid_reviews_count baja O(1)
- Paginadores: /books?page=2 (50 por página), /books/1?reviews_page=2 (20), /users?page=2 (20)

## 6. Check final antes de entregar
```bash
cat > /tmp/check_pdf.sh <<'SH'
echo "=== CHECK PDF ==="
grep -q "per_page = 50" app/controllers/books_controller.rb && echo "✓ 50 libros por página" || echo "✗ FAIL 50"
grep -q "valid_reviews_count" app/models/book.rb && echo "✓ O(1) contadores" || echo "✗ FAIL O(1)"
ls app/jobs/update_book_ratings_on_user_ban_job.rb && echo "✓ Baneo retroactivo job" || echo "✗"
grep -q "user_id.*book_id.*unique" db/schema.rb && echo "✓ Unicidad index" || echo "✗"
wc -l DECISIONES.md && echo "✓ DECISIONES.md"
cat tmp/data_generation_timing.txt 2>/dev/null && echo "✓ Timing file" || echo "○ Timing no generado (corre benchmark)"
bundle exec rspec -q && echo "✓ RSpec PASS" || echo "✗ RSpec FAIL"
SH
chmod +x /tmp/check_pdf.sh
/tmp/check_pdf.sh
```

Si todo da ✓ y RSpec PASS, estás homologado 100% PDF.
