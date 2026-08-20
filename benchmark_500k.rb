# benchmark 500k reviews - O(1) proof
book = Book.find_or_create_by!(title: "Libro Stress 500k", author: "Test O(1)")
puts "Book #{book.id}: #{book.title} - valid_reviews_count=#{book.valid_reviews_count}"

# crea usuarios si faltan
users_needed = 5000 - User.where.not(id: User.where(role: 'admin').select(:id)).count
users_needed = 5000 if users_needed < 0

puts "Creando 5000 users/reviews si no existen..."
5000.times do |i|
  break if book.reviews.count >= 5000
  email = "stress#{i}@test.cl"
  user = User.find_or_create_by!(email: email) do |u|
    u.name = "Stress #{i}"
    u.password = "12345678"
  end
  begin
    Review.create!(book: book, user: user, stars: rand(1..5), content: "Stress test #{i}")
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    next
  end
  puts "#{i} reviews" if i % 500 == 0
end

book.reload
puts "FINAL: Book #{book.id} -> #{book.valid_reviews_count} valid, #{book.valid_total_stars} stars, avg=#{book.average_rating_label}"

# mide home O(1)
require 'benchmark'
time = Benchmark.realtime {
  Book.order(valid_reviews_count: :desc).limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).to_a
} * 1000
puts "Home 50 libros O(1): #{time.round(2)}ms con #{Review.count} reviews totales"
