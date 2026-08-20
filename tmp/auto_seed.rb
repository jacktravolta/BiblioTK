puts ">> AUTO SEED CHECK..."
require 'set'
if Book.count >= 10 && User.count >= 20 && Review.count >= 200
  puts ">> YA HAY DATOS: #{Book.count} libros, #{User.count} users, #{Review.count} reviews - skip"
  exit
end
puts ">> SEED 10/20/200"

# ADMIN EXACTO que pides
admin = User.where(email: "admin@bibliotk.cl").first_or_create! { |u| u.name="Admin"; u.password="123456"; u.role="admin" }
admin.update!(role: "admin", banned: false, password: "123456", password_confirmation: "123456")

# USER1 EXACTO que pides: user1@test.com / 12345678
u1 = User.where(email: "user1@test.com").first_or_create! { |u| u.name="User 1"; u.password="12345678"; u.role="user" }
u1.update!(role: "user", banned: false, password: "12345678", password_confirmation: "12345678")

10.times { |i| Book.where(title: "Libro #{i+1}").first_or_create! { |b| b.author="Autor #{(i%20)+1}" } }
books = Book.all.to_a

# resto de users 2..20 en .com para que coincida con tu login
19.times do |i|
  email="user#{i+2}@test.com"
  User.where("lower(email)=?", email.downcase).first_or_create! { |u| u.name="User #{i+2}"; u.email=email; u.password="12345678"; u.role="user"; u.banned=false }
end
users = User.where(role:"user").to_a

Review.delete_all
Book.update_all(valid_reviews_count:0, total_stars:0) rescue nil

used=Set.new; c=0
while c<200
  b=books.sample; u=users.sample; k="#{u.id}-#{b.id}"
  next if used.include?(k)
  used.add(k)
  Review.create!(user_id:u.id, book_id:b.id, stars:rand(1..5), comment:"Auto #{c+1}")
  c+=1
end
Book.find_each { |b| ReconcileBookRatingJob.new.perform(b.id) rescue nil }
puts ">> SEED OK - Login user: user1@test.com / 12345678 - Login admin: admin@bibliotk.cl / 123456"
