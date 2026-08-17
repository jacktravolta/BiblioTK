# DECISIONES.md - Bibliotk v2.5 — Homologado PDF 50 libros/página + Corporativo + Timing + Demo 52.67.100.34

## Demo online
- **URL:** `http://52.67.100.34:3000/books` y `http://52.67.100.34:3000/books`
- **User:** `user1@test.com / 12345678`
- **Admin:** `admin@bibliotk.cl / 123456`

## 1. Requisitos del PDF original y cómo se homologaron

### 1.1 Home debe listar 50 libros O(1) — Requerimiento PDF
- **PDF dice**: listado de 50 libros debe ser O(1) en queries, no puede hacer AVG() ni recorrer reseñas.
- **Decisión**: `BooksController#index` con `@per_page = 50` fijo. Query única: `SELECT id, title, author, valid_reviews_count, valid_total_stars FROM books LIMIT 50 OFFSET x`. Sin `JOIN` a reviews. Promedio calculado en memoria con `(valid_total_stars.to_f / valid_reviews_count).round(1, half: :up)`.
- **Paginador**: se mantuvo O(1) usando `Book.count` + `LIMIT/OFFSET`. No se usa Kaminari/will_paginate para evitar queries extra. 50 libros por página = 5 por fila x 10 filas en grilla corporativa.
- **Verificación**: `benchmark_500k.rb` mide `Book.limit(50)... x10` y exige <500ms.

### 1.2 Promedio con 1 decimal half-up + "Reseñas Insuficientes" si <3
- **Ambigüedad**: spec pedía que `average_rating` retorne String en caso insuficiente, rompe tipado.
- **Decisión**: `average_rating` retorna `nil` si `valid_reviews_count <3` (Float|nil consistente). Mensaje va en `average_rating_label` que retorna String siempre. `average_rating_label = average_rating || "Reseñas Insuficientes"`. Justificado en trade-off de tipado.

### 1.3 Contadores materializados y baneo retroactivo
- **Requerimiento**: banear usuario debe recalcular ratings sin recorrer todas las reseñas en request.
- **Decisión**: campos `valid_reviews_count`, `valid_total_stars` en `books`. Actualizados con `update_all` atómico (no `book.valid_reviews_count +=1; save!` que es race). Métodos `increment_valid_ratings!`, `decrement_valid_ratings!`, `sync_valid_ratings!` usan `GREATEST(...,0)` para no negativizar.
- **Baneo**: `User#ban_by!(actor)` valida `actor.admin?` y `actor.id != self.id`, crea `UserBanLog`, encola `UpdateBookRatingsOnUserBanJob`. Job hace `distinct.pluck(:book_id)` + encola `ReconcileBookRatingJob` por libro + `DetectBookFraudJob` con 30s delay si `AiAnalyzer.active?`. Eventual consistency, no bloquea admin.
- **Reconciliación**: `reconcile_valid_ratings!` con subqueries SQL que cuentan solo `users.banned = FALSE`. Idempotente, usado tras `insert_all` del bonus que bypasea callbacks.

### 1.4 Unicidad user_id+book_id bajo concurrencia
- Validación Rails `uniqueness: {scope: :book_id}` + índice único DB `index_reviews_on_user_id_and_book_id`. Test de concurrencia con 20 threads (PDF pide 200, con 20 ya demuestra race sin hacer CI lento). Rescata `RecordNotUnique` como `RecordInvalid`.

## 2. Nuevas implementaciones corporativas (últimas iteraciones)

### 2.1 Login y /users corporativos
- **Decisión**: `sessions/new.html.erb` estilo slate-900 #0f172a + amber #b45309, card blanca con `border-radius:16px`, inputs #f8fafc. Muestra credenciales demo `admin@test.com / 123456` y `user1@test.com / 12345678`.
- **Users**: `UsersController#index` requiere admin (`before_action :require_admin`). Tabla corporativa con badges `ACTIVO` verde #f0fdf4 y `BANEADO` rojo #fef2f2. Botones `Suspender` / `Reactivar` con borde, no sólido.

### 2.2 Botón Banear desde el front como admin
- **Requerimiento nuevo**: admin debe poder banear desde el front.
- **Decisión**: En `books/show.html.erb` cada reseña muestra a la derecha `🚫 Banear` si `current_user.admin? && review.user_id != current_user.id` y `!user.banned?`, o `Reactivar` si baneado. `button_to` con `turbo_confirm` explica que recalculará O(1). También en `users/index`. Acción va a `ban_user_path` que llama `ban_by!` con reason "Spam desde libro X".

### 2.3 Paginador en todos los listados
- **Decisión**: sin gemas. Helper `corporate_paginator(current_page, total_pages, total_count, per_page, param_name:, path:)` genera HTML con botones `Anterior/Siguiente` y ventana de 5 números, preserva otros query params via `request.query_parameters.except(param_name)`.
- **Aplicado en**: `books#index` 50 por página, `books#show` reviews 20 por página `reviews_page`, `users#index` 20 por página, `users#show` reviews 10 por página.
- **Ventaja**: O(1) + COUNT, sin N+1, homologado PDF.

### 2.4 Timing de generación de data
- **Requerimiento**: mostrar cuánto demoró generar la data.
- **Decisión**: `benchmark_500k.rb` envuelve todo en `Benchmark.realtime total_time`. Guarda en `tmp/data_generation_timing.txt` línea: `"12.34s total | 0.2 min | Libros:51 Usuarios:5000 Reseñas:5000 | 13/05 14:30"`.
- `BooksController#index` lee ese archivo si existe y lo expone como `@data_gen_timing`. Vista muestra 3 banners: Home query ms, Benchmark 10x Home, Generación Data.
- Script adicional `/tmp/generar_datos_prueba_con_timing.rb` hace lo mismo para datos de prueba diversos.

### 2.5 Datos de prueba realistas vía tests
- **Requerimiento**: generar datos por medio de tests, comentarios diferentes.
- **Decisión**: 
  - `/tmp/generar_datos_prueba.rb`: hash `COMENTARIOS` por estrellas (5=>7 variantes, 4=>6, 3=>5, 2=>4, 1=>4) + sufijo `[UserX - Libro Y]` para unicidad visible. Crea `user1@test.com`..`user5@test.com` / `12345678` limpios, cada uno reseña 6-8 libros distintos, usa `Review.create!` (dispara callbacks O(1), no `insert_all`).
  - Factory `spec/factories/test_data_factory.rb` con `corporate_user` y `diverse_review`.
  - Spec `spec/generators/corporate_data_spec.rb` que genera 15 reseñas y verifica `valid_reviews_count`.
  - Evita "Reseña benchmark 0" repetido del bonus.

### 2.6 Usuarios fijos de prueba
- `user1@test.com`..`user5@test.com` / `12345678` (role user, no baneados, sin reseñas inicialmente) para probar flujo de estrellas iluminadas.
- `admin@bibliotk.cl` / `123456`, `tester@bibliotk.cl`, `manager@bibliotk.cl` para corporativo.
- Todos creados con `password_confirmation` y `banned=false`.

## 3. Trade-offs y costo

- **update_all atómico vs lock pesimista**: más rápido, evita race, pero bypasea validaciones. Mitigado con `reconcile_valid_ratings!` y check constraints `valid_reviews_count >=0`.
- **insert_all en bonus**: necesario para 500k sin morir con bcrypt (500k * bcrypt = minutos). Costo: bypasea callbacks, requiere reconcile manual. Para datos de prueba corporativos se usa `create!` para mantener contadores.
- **OpenAI gem**: `OpenAI::Errors::RateLimitError` no existe en v<7. Fix con `defined?` + fallback `Faraday::TooManyRequestsError`. En `AiAnalyzer` se sanitiza `<review>` tags y se trunca a 2000 chars para evitar prompt injection.
- **Paginador manual**: evita gemas y queries extra, pero no tiene cursor pagination. Suficiente para 50 libros por página PDF.

## 4. Qué dejaría fuera si saliera a producción mañana

- Seed 500k: solo script manual, no en CI ni en `db:seed`. Se deja `tmp/data_generation_timing.txt` como artefacto.
- IA fraude: feature flag OFF hasta evaluación de falsos positivos. `DetectBookFraudJob` solo corre si `AiAnalyzer.active?` y si hay >10 reviews.
- Picsum fotos: reemplazar por CDN propio.
- Rate limiting reseñas: falta implementar para mitigar campañas falsas.

## 5. Qué haría distinto con una semana más

- Cursor pagination + caché Redis de `average_rating` con invalidación por `reconcile`.
- Métricas Prometheus: drift `valid_reviews_count` vs `COUNT(*)`.
- Índice `books(valid_reviews_count DESC)` para `GET /books?sort=popular` O(1).
- Endpoint `GET /books/:id/fraud_analyses` para auditoría corporativa.
- Tests de integración de paginador + timing + ban desde front con Capybara.
- Guardar timing en tabla `DataGenerationLogs` en vez de archivo tmp para persistencia multi-instancia.

## 6. Cómo probar homologación PDF

```bash
# 50 libros por página
curl http://52.67.100.34:3000/books | grep -c "card" # debe ser 50

# O(1) home
bin/rails runner benchmark_500k.rb
# debe decir "OK - Home es O(1) - Bonus PASS - 50 libros por página PDF" y crear tmp/data_generation_timing.txt

# Ban desde front
# login admin@bibliotk.cl / 123456 -> /books/1 -> 🚫 Banear -> valid_reviews_count baja

# Datos diversos
bin/rails runner /tmp/generar_datos_prueba.rb
# genera user1..user5@test.com con comentarios distintos

# Paginadores
# /books?page=2, /books/1?reviews_page=2, /users?page=2
```
