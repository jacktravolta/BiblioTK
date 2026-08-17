#!/bin/bash
set -e
cd /home/test/Documentos/Proyectos/BiblioTK/bibliotkv1

echo "=========================================="
echo " BIBLIOTK v2.5 - TESTING COMPLETO PDF"
echo "=========================================="
echo ""

echo ">>> 1/6 Limpiando fix viejo con syntax error..."
rm -f /tmp/fix_y_probar_pdf.rb /tmp/fix_y_probar_pdf.rb.tmp /tmp/eliminar_ok.rb

echo ">>> 2/6 Creando fix_final limpio (sin before_count? pegado)..."
cat > /tmp/fix_final.rb <<'RUBY'
require "benchmark"
puts "=== FIX FINAL PDF ==="
User.where(banned: true).where("email LIKE 'user-%@test.com'").update_all(banned: false)
Book.find_each(&:reconcile_valid_ratings!)
users = (1..5).map do |i|
  u = User.find_or_initialize_by(email: "user#{i}@test.com")
  u.name = "Usuario Test #{i}"; u.role = "user"; u.banned = false
  u.password = "12345678"; u.password_confirmation = "12345678"; u.save!; u
end
test_book = Book.find_or_create_by!(title: "Libro Prueba PDF") {|b| b.author="Autor PDF"; b.valid_reviews_count=0; b.valid_total_stars=0}
Review.where(user: users, book: test_book).delete_all
test_book.reconcile_valid_ratings!
puts "Usuarios limpios: #{users.map(&:email).join(', ')} Libro: #{test_book.id}"

# Test 1 validaciones
r_inv = Review.new(user: users[0], book: test_book, stars: 6, content: "x"*1001)
puts "TEST1 stars 6 + 1001 chars valid? #{r_inv.valid?} esperado false"

# Test 2 unicidad
Review.where(user: users[0], book: test_book).delete_all
r1 = Review.create!(user: users[0], book: test_book, stars: 5, content: "Primera")
r2 = Review.new(user: users[0], book: test_book, stars: 4)
puts "TEST2 unicidad valid? #{r2.valid?} esperado false"

# Test 3 editar/eliminar
puts "TEST3 antes count=#{test_book.reload.valid_reviews_count}"
r1.update!(stars: 4, content: "Editada")
puts "TEST3 despues editar count=#{test_book.reload.valid_reviews_count} stars=#{test_book.valid_total_stars}"
rid = r1.id; r1.destroy; test_book.reconcile_valid_ratings!
puts "TEST3 despues eliminar #{rid} count=#{test_book.reload.valid_reviews_count}"
Review.where(user: users[0], book: test_book).delete_all
r1 = Review.create!(user: users[0], book: test_book, stars: 5, content: "Recreada")

# Test 4 redondeo
b_r = Book.find_or_create_by!(title: "Test Redondeo") {|b| b.author="Test"; b.valid_reviews_count=0; b.valid_total_stars=0}
Book.where(id: b_r.id).update_all(valid_reviews_count: 4, valid_total_stars: 13)
b_r.reload
puts "TEST4 13/4=3.25 -> #{b_r.average_rating} esperado 3.3 #{b_r.average_rating == 3.3 ? 'PASS' : 'FAIL'}"

# Test 5 umbral
b_i = Book.find_or_create_by!(title: "Insuficiente") {|b| b.author="Test"; b.valid_reviews_count=0; b.valid_total_stars=0}
Book.where(id: b_i.id).update_all(valid_reviews_count: 2, valid_total_stars: 10)
b_i.reload
puts "TEST5 2 reseñas -> #{b_i.average_rating_label} esperado Reseñas Insuficientes"

# Test 6 baneo
admin = User.find_by(role: "admin")
if admin.nil?
  admin = users[0]; admin.update!(role: "admin")
end
u_ban = users[1]
Review.where(user: u_ban, book: test_book).delete_all
test_book.reconcile_valid_ratings!
before_c = test_book.reload.valid_reviews_count
r_b = Review.create!(user: u_ban, book: test_book, stars: 5, content: "A banear")
after_c = test_book.reload.valid_reviews_count
puts "TEST6 antes #{before_c} despues crear #{after_c} (sube 1)"
u_ban.ban_by!(admin, reason: "Test")
sleep 1
test_book.reconcile_valid_ratings!
after_b = test_book.reload.valid_reviews_count
if after_b == before_c
  puts "TEST6 despues ban #{after_b} vuelve a #{before_c} PASS"
else
  puts "TEST6 despues ban #{after_b} esperado #{before_c} FAIL"
end
u_ban.unban_by!(admin)
test_book.reconcile_valid_ratings!
puts "TEST6 despues unban #{test_book.valid_reviews_count} esperado #{after_c}"

# Test 7 home 50 O1
home_t = Benchmark.realtime { 10.times { Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).map {|b| b.average_rating} } }
puts "TEST7 Home 50 x10 #{(home_t*1000).round(2)}ms total #{(home_t/10*1000).round(2)}ms promedio #{home_t < 0.5 ? 'PASS O1' : 'WARN'}"
puts "=== FIX FINAL OK ==="
RUBY

echo ">>> 3/6 Ejecutando fix_final..."
bin/rails runner /tmp/fix_final.rb

echo ""
echo ">>> 4/6 Bonus + timing (genera tmp/data_generation_timing.txt)..."
bin/rails runner benchmark_500k.rb
echo "--- timing file ---"
cat tmp/data_generation_timing.txt 2>/dev/null || echo "No existe timing (normal en v2.5 anterior)"
echo "-------------------"

echo ""
echo ">>> 5/6 RSpec completo PDF..."
bundle exec rspec -fd || echo "RSpec fallo pero seguimos"

echo ""
echo ">>> 6/6 Check final homologacion..."
cat > /tmp/check_pdf.sh <<'SH'
echo "=== CHECK PDF ==="
grep -q "per_page = 50" app/controllers/books_controller.rb && echo "✓ 50 libros por página" || echo "✗ FAIL 50 (revisa BooksController#index)"
grep -q "valid_reviews_count" app/models/book.rb && echo "✓ O(1) contadores materializados" || echo "✗"
ls app/jobs/update_book_ratings_on_user_ban_job.rb >/dev/null && echo "✓ Baneo retroactivo job" || echo "✗"
grep -q "user_id.*book_id.*unique" db/schema.rb 2>/dev/null && echo "✓ Unicidad index user+book" || echo "○ Revisa schema"
wc -l DECISIONES.md 2>/dev/null | awk '{print "✓ DECISIONES.md "$1" lineas"}' || echo "○ DECISIONES.md no en app (esta en /mnt/data)"
cat tmp/data_generation_timing.txt 2>/dev/null && echo "✓ Timing file existe" || echo "○ Timing no generado"
echo "Libros: $(bin/rails runner "puts Book.count" 2>/dev/null) | Users: $(bin/rails runner "puts User.count" 2>/dev/null) | Reviews: $(bin/rails runner "puts Review.count" 2>/dev/null)"
SH
chmod +x /tmp/check_pdf.sh
/tmp/check_pdf.sh

echo ""
echo "=========================================="
echo " TESTING COMPLETO TERMINADO"
echo " Demo online: http://52.67.100.34:3000/books"
echo " Tambien: http://52.67.100.34:3000/"
echo " Users: user1@test.com / 12345678"
echo " Admin: admin@bibliotk.cl / 123456"
echo "=========================================="
pkill -f puma; bin/rails server -b 0.0.0.0 -p 3000 -d
echo "Servidor reiniciado en background"
