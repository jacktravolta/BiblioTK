require 'benchmark'
<<<<<<< HEAD
require 'fileutils'

total_time = Benchmark.realtime do
  # 1. 50 libros base si no existen
  if Book.count < 50
    books = 50.times.map { |i| { title: "Libro Base #{i}", author: "Autor Base #{i}", valid_reviews_count: 0, valid_total_stars: 0, created_at: Time.now, updated_at: Time.now } }
    Book.insert_all(books)
  end
  
  book = Book.find_or_create_by!(title: "Libro Popular", author: "Autor Test")
  
  SEED_COUNT = 5000
  BATCH_SIZE = 5000
  
  needed = SEED_COUNT - User.count
  if needed > 0
    puts "Creando #{needed} usuarios..."
    digest = BCrypt::Password.create("123456")
    (0...(needed.to_f/BATCH_SIZE).ceil).each do |b|
      size = [BATCH_SIZE, needed - b*BATCH_SIZE].min
      batch = size.times.map { |i| idx = b*BATCH_SIZE + i; { name: "User #{idx}", email: "user-#{idx}-#{SecureRandom.hex(4)}@test.com", password_digest: digest, created_at: Time.now, updated_at: Time.now, role: "user" } }
      User.insert_all(batch)
=======

book = Book.find_or_create_by!(title: "Libro Popular", author: "Autor Test")
puts "Libro: #{book.id}"

total_time = Benchmark.realtime do
  if book.reviews.count < 500_000
    puts "Creando 500k reseñas (batch insert)..."
    users = []
    1000.times { users << User.create!(name: "User #{SecureRandom.hex(4)}", email: "user-#{SecureRandom.hex(8)}@test.com", password: "123456") }
    reviews = []
    500_000.times do |i|
      reviews << { user_id: users[i % users.size].id, book_id: book.id, stars: rand(1..5), content: "Reseña #{i}", created_at: Time.now, updated_at: Time.now }
      if reviews.size >= 5000
        Review.insert_all(reviews)
        reviews = []
        print "."
      end
>>>>>>> 57469fc (Correccion comando ruby de pruebas)
    end
    Review.insert_all(reviews) if reviews.any?
    puts ""
    book.reconcile_valid_ratings!
  end
<<<<<<< HEAD
  
  if Review.count < SEED_COUNT
    user_ids = User.order(:id).limit(SEED_COUNT).pluck(:id)
    user_ids.each_slice(BATCH_SIZE) do |slice|
      reviews = slice.map { |uid| { user_id: uid, book_id: book.id, stars: rand(1..5), content: "Reseña benchmark #{SecureRandom.hex(2)}", created_at: Time.now, updated_at: Time.now } }
      Review.insert_all(reviews)
    end
    book.reconcile_valid_ratings!
  end
=======
>>>>>>> 57469fc (Correccion comando ruby de pruebas)
end

puts "valid_reviews_count: #{book.valid_reviews_count}"

time_home = Benchmark.realtime do
  10.times do
    Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).map { |b| [b.title, b.average_rating] }
  end
end

# Guarda los 3 datos en tmp/data_generation_timing.txt como dice DECISIONES.md 2.4
FileUtils.mkdir_p("tmp")
timing_line = "#{total_time.round(2)}s total | #{(total_time/60.0).round(2)} min | Libros:#{Book.count} Usuarios:#{User.count} Reseñas:#{Review.count} | #{Time.now.strftime('%d/%m %H:%M')} | Home 50 x10: #{time_home.round(3)}s (#{(time_home/10*1000).round(2)}ms por req)"
File.write("tmp/data_generation_timing.txt", timing_line)
puts timing_line
puts "Home 50 libros x10 en #{time_home.round(3)}s - O(1) independiente de 500k reseñas"
puts "Promedio por request: #{(time_home/10*1000).round(2)}ms"
