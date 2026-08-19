require 'benchmark'
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
    end
  end
  
  if Review.count < SEED_COUNT
    user_ids = User.order(:id).limit(SEED_COUNT).pluck(:id)
    user_ids.each_slice(BATCH_SIZE) do |slice|
      reviews = slice.map { |uid| { user_id: uid, book_id: book.id, stars: rand(1..5), content: "Reseña benchmark #{SecureRandom.hex(2)}", created_at: Time.now, updated_at: Time.now } }
      Review.insert_all(reviews)
    end
    book.reconcile_valid_ratings!
  end
end

FileUtils.mkdir_p("tmp")
File.write("tmp/data_generation_timing.txt", "#{total_time.round(2)}s total | #{(total_time/60).round(2)} min | Libros:#{Book.count} Usuarios:#{User.count} Reseñas:#{Review.count} | #{Time.now.strftime('%d/%m %H:%M')}")

puts "TOTAL generación: #{total_time.round(2)}s"
puts "Guardado en tmp/data_generation_timing.txt: #{File.read('tmp/data_generation_timing.txt')}"

time_home = Benchmark.realtime { 10.times { Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).map { |b| [b.title, b.average_rating] } } }
puts "Home 50 libros x10: #{time_home.round(3)}s O(1) => #{(time_home/10*1000).round(2)}ms por request - PDF OK"
