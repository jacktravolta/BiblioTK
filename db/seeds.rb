puts ">> AUTO SEED CHECK..."
require 'set'
if Book.count >= 10 && User.count >= 200 && Review.count >= 200
  puts ">> YA HAY DATOS: #{Book.count} libros, #{User.count} users, #{Review.count} reviews - skip"
  exit
end
puts ">> SEED 10 / 200 / 200"

# ADMIN
admin = User.where(email: "admin@bibliotk.cl").first_or_create! { |u| u.name="Admin"; u.password="123456"; u.role="admin" }
admin.update!(role:"admin", banned:false, password:"123456", password_confirmation:"123456")

# 200 USERS user1@test.com .. user200@test.com / 12345678
200.times do |i|
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

10.times { |i| Book.where(title:"Libro #{i+1}").first_or_create! { |b| b.author="Autor #{(i%20)+1}" } }
books=Book.all.to_a
users=User.where(role:"user").order(:id).to_a

Review.delete_all
Book.update_all(valid_reviews_count:0, total_stars:0) rescue nil

used=Set.new; c=0
while c<200
  b=books.sample; u=users.sample; k="#{u.id}-#{b.id}"
  next if used.include?(k)
  used.add(k)
  Review.create!(user_id:u.id, book_id:b.id, stars:rand(1..5), comment:"Review #{c+1} auto")
  c+=1
end
Book.find_each { |b| ReconcileBookRatingJob.new.perform(b.id) rescue nil }

File.write("tmp/data_generation_timing.txt","#{Time.now} - #{User.count} users, #{Book.count} books, #{Review.count} reviews\n")
puts ">> SEED OK: Login user: user1@test.com / 12345678 (hasta user200) - Login admin: admin@bibliotk.cl / 123456"
