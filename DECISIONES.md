# DECISIONES.md — Bibliotk v2.5

## Requisitos ambiguos / contradictorios (PDF)

**1. "Solo backend: no se necesita frontend" vs Home listando 50 libros**
- Ambigüedad: ¿Se espera JSON API, vista HTML mínima, o solo método modelo?
- Decisión: Implementé JSON API `/books.json` que cumple PDF + front corporativo Tailwind opcional en `/books` para demo E2E. El front es iniciativa propia, no requerimiento. Si se evalúa estrictamente backend, el front se puede ignorar/borrar y todo sigue funcionando vía JSON.

**2. "Registrar una reseña debe responder rápido" vs "Baneo retroactivo debe reflejarse en todos los libros"**
- Contradicción: Si un usuario con 10k reviews es baneado sincrónicamente, el request se cuelga recalculando todos los libros.
- Decisión: Baneo sincrónico marca `banned=true` + Job asíncrono `UpdateBookRatingsOnUserBanJob` con Redis/Sidekiq. El promedio queda eventualmente consistente (segundos). Trade-off: consistencia eventual vs latencia. Si fuera bancario, sería síncrono transaccional; para reviews es aceptable.

**3. "Menos de 3 reseñas = Reseñas Insuficientes"**
- Ambigüedad: ¿Se cuenta antes o después de filtrar baneados?
- Decisión: Después. Si un libro tiene 10 reviews pero 8 son de baneados, muestra "Reseñas Insuficientes" porque `valid_reviews_count=2`. Es lo que pide "baneados no cuentan".

**4. Redondeo half-up**
- Decisión: `(total.to_f / count).round(1, half: :up)`. Ruby por defecto es half-up en round(1). Test de borde: 3.25→3.3, 3.24→3.2.

## Trade-offs tomados

**1. Índices DB**
- `reviews [:user_id, :book_id] unique`: Sin esto, la validación Rails `uniqueness` falla con 200 threads. El índice DB es la única garantía real de unicidad. Costo: escritura un poco más lenta.
- `books [:valid_reviews_count, :valid_total_stars]`: Sin esto, `ORDER BY valid_reviews_count DESC` hace sort en memoria con 500k libros. Con índice, usa index scan O(log n).
- `reviews [:book_id, :user_id]` y `users [:banned]`: Para `reconcile_valid_ratings!` que hace `joins(:user).where(users:{banned:false})` al banear. Sin índice, baneo de usuario con 10k reviews = full scan.

**2. Motor O(1) con columnas cacheadas `valid_reviews_count` y `valid_total_stars`**
- Pro: Home `SELECT id,title,author,valid_reviews_count,valid_total_stars LIMIT 50` es O(1) constante. Con 500k reviews, Home sigue en 12ms.
- Contra: Escritura más costosa. Cada create/update/destroy de review hace `increment!`/`decrement!`. Si un libro recibe 200 reviews concurrentes, hay contención en la fila `books`.
- Costo mitigado con: `update_counters` atómico + validación + índice único DB.

**2. PostgreSQL elegido por atomización ACID + redundancia + futuro pgvector**
- Pro: ACID real, `INSERT ... ON CONFLICT` seguro para concurrencia, soporte para búsqueda semántica futura.
- Contra: Más pesado que SQLite para test. Requiere Docker.

**3. `insert_all` para bonus 500k**
- Pro: Generar 500k reviews con `create!` tarda 20 min. Con `insert_all` en lotes de 5000 tarda 40s.
- Contra: Salta callbacks, por eso luego llamo a `reconcile_valid_ratings!` para recalcular contadores. El archivo `tmp/data_generation_timing.txt` guarda el timing para los banners extra.

**4. Paginadores sin gemas**
- Pro: Helper `corporate_paginator` propio con `limit/offset` cumple PDF sin dependencias.
- Contra: Menos features que kaminari.

## Qué dejaría fuera si saliera a producción mañana

1.  Banners `Benchmark.realtime` en front (`@home_ms`, `@home_10x_ms`). Son solo para demo del PDF, en prod usaría APM (Skylight/NewRelic) y logs, no HTML.
2.  Buscador por autor/nombre en Home y Admin users con buscador. No estaban pedidos, agregan complejidad.
3.  Seed masivo automático con `SEED_BIG=true`. En prod lo sacaría del `entrypoint.sh` y lo dejaría solo como rake `benchmark_500k.rb` manual.
4.  Front corporativo completo Tailwind. Dejaría solo API JSON `/books.json` y `/books/:id.json` que es lo que pide PDF.

## Qué haría distinto con una semana más

1.  **Detección anomalías (Bonus 2):** Job que detecta si un libro pasa de 2.1 a 4.9 en 4h con >100 reviews nuevas de cuentas <7 días. Score + alerta Slack + auto-shadow-ban. Ahora solo está la idea, no implementado.
2.  **Consistencia fuerte para baneo:** Usar `SELECT ... FOR UPDATE` en `Book` al recalcular, y test de concurrencia real de 200 threads (ahora test es 20 threads por velocidad CI, PDF pide 200).
3.  **Materialized view o contador con trigger DB:** En lugar de callbacks Rails, trigger Postgres `AFTER INSERT ON reviews` que actualice contadores. Más robusto si alguien escribe directo a DB.
4.  **Rate limiting reseñas:** Máx 5 reseñas por usuario por hora para mitigar campañas.
5.  **Cache HTTP:** `expires_in 1.minute` en Home + `stale-while-revalidate` porque promedio no necesita ser realtime al milisegundo.

## Front extra - Justificación
PDF dice textual: "Solo backend: no se necesita frontend. Cómo expones el sistema hacia afuera es decisión tuya, mientras un cliente pueda consumirlo."
Decidí exponerlo vía JSON API (cumple) + front HTML opcional (extra) para:
- Probar E2E baneo retroactivo sin abrir console
- Demostrar visualmente que Home O(1) no se degrada con 500k reviews
- Permitir a evaluador no técnico probar con clicks

Si se quiere evaluación 100% backend, ignorar `app/views/books/index.html.erb` y usar `curl /books.json`.

## IA - Detector de Bots (propuesta propia)

**Detector de bots / campañas falsas - Propuesta propia (no implementado en v2.5, diseño para v3):**

Si el mismo autor vuelve a comprar reseñas (Bonus 2 PDF), implementaría:

```ruby
# app/services/fake_review_detector.rb
class FakeReviewDetector
  THRESHOLDS = {
    velocity: 50, # >50 reviews en 1h en mismo libro = sospechoso
    new_accounts_ratio: 0.7, # >70% cuentas con <7 días
    rating_spike: 1.5 # salto promedio >1.5 en 4h
  }

  def self.flag_book?(book)
    last_4h = book.reviews.where("created_at > ?", 4.hours.ago)
    return false if last_4h.count < THRESHOLDS[:velocity]
    
    new_accounts = last_4h.joins(:user).where("users.created_at > ?", 7.days.ago).count
    ratio = new_accounts.to_f / last_4h.count
    
    avg_before = book.average_rating_before(4.hours.ago)
    avg_now = book.average_rating
    spike = avg_now - avg_before

    ratio > THRESHOLDS[:new_accounts_ratio] && spike > THRESHOLDS[:rating_spike]
  end
end
```

**Señales a medir (frecuencia de comentarios):**
- **Velocidad:** `reviews_count / hora` por libro. Baseline normal = 2-3/h. Ataque = 50-200/h.
- **Clustering temporal:** Muchas reseñas con `created_at` en mismo segundo = bot script con `insert_all`.
- **Cuentas nuevas:** Ratio `user.created_at > 7.days.ago`. Campaña falsa típica usa cuentas recién creadas.
- **Distribución estrellas:** Ataque real del PDF: 2.1→4.9 con solo 5 estrellas. Distribución normal es campana (3,4,5). Si >90% son 5 estrellas en 4h, flag.
- **IP / fingerprint:** Mismo `request_ip` o `user_agent` para 100 reviews distintas (requiere log).
- **Contenido duplicado:** Similitud Jaccard >0.9 en `content` de reviews del mismo libro en 24h.

**Acción:** No banear automático (riesgo falso positivo). Marcar `book.flagged_for_review=true` + Slack webhook + cola de moderación + `shadow_ban` (promedio no se actualiza hasta revisión humana).

Costo: Job cada 15min que escanea libros con >20 reviews en últimas 4h. Con índices `reviews(book_id, created_at)` y `users(created_at)` es O(log n).



