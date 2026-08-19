if Book.count == 0
  50.times { |i| Book.create!(title: "Libro Base #{i}", author: "Autor Base #{i}", valid_reviews_count: 0, valid_total_stars: 0) }
  User.create!(email: 'admin@bibliotk.cl', name: 'Admin BiblioTK', password: '123456', password_confirmation: '123456', role: 'admin') unless User.exists?(email: 'admin@bibliotk.cl')
  User.create!(email: 'admin@test.com', name: 'Admin Test', password: '123456', password_confirmation: '123456', role: 'admin') unless User.exists?(email: 'admin@test.com')
  (1..5).each { |i| User.find_or_create_by!(email: "user#{i}@test.com") { |u| u.name = "Usuario #{i}"; u.password = '12345678'; u.password_confirmation = '12345678'; u.role = 'user' } }
end
if ENV['SEED_BIG'] == 'true' && Review.count < 4000 && File.exist?('benchmark_500k.rb')
  puts ">> SEED_BIG 5000..."; load 'benchmark_500k.rb'
end
