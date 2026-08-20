puts ">> AUTO SEED CHECK..."
require 'set'
seed_big = ENV['SEED_BIG'] == 'true'
target_books = 50
target_users = 7
target_reviews = seed_big ? 5000 : 0

puts ">> SEED_BIG=#{seed_big} -> objetivo: #{target_books} libros, #{target_users} users, #{target_reviews} reviews"

if Book.count >= target_books && User.where(role:"user").count >= target_users && Review.count >= target_reviews
  puts ">> YA HAY DATOS: #{Book.count}/#{User.where(role:"user").count}/#{Review.count} - skip"
  exit
end

# ADMIN
admin = User.where(email: "admin@bibliotk.cl").first_or_create! { |u| u.name="Admin"; u.password="123456"; u.role="admin" }
admin.update!(role:"admin", banned:false, password:"123456", password_confirmation:"123456")

# 7 USERS DEMO: user1@test.com .. user7@test.com / 12345678
7.times do |i|
  email="user#{i+1}@test.com"
  u = User.where("lower(email)=?", email.downcase).first_or_initialize
  u.name="User #{i+1}"
  u.email=email
  u.password="12345678"
  u.password_confirmation="12345678"
  u.role="user"
  u.banned=false
  u.save!
end

50.times { |i| Book.where(title:"Libro #{i+1}").first_or_create! { |b| b.author="Autor #{(i%20)+1}" } }
books=Book.all.to_a
users=User.where(role:"user").to_a

if seed_big
  Review.delete_all
  Book.update_all(valid_reviews_count:0, total_stars:0) rescue nil
  used=Set.new; c=0
  while c < 5000
    b=books.sample; u=users.sample; k="#{u.id}-#{b.id}"
    next if used.include?(k)
    used.add(k)
    Review.create!(user_id:u.id, book_id:b.id, stars:rand(1..5), comment:"Review #{c+1} auto BIG")
    c+=1
    puts ">> #{c}/5000" if c % 500 == 0
  end
else
  puts ">> SEED_BIG=false, no se generan 5000 reviews (solo libros + users)"
end

Book.find_each { |b| ReconcileBookRatingJob.new.perform(b.id) rescue nil }
File.write("tmp/data_generation_timing.txt","#{Time.now} - BIG=#{seed_big} - #{User.count} users, #{Book.count} books, #{Review.count} reviews\n")
puts ">> SEED OK: #{Book.count} books, #{User.where(role:'user').count} demo users, #{Review.count} reviews - Login: user1@test.com / 12345678"
