puts ">> AUTO SEED CHECK..."
require 'set'
if Book.count >= 100 && User.count >= 200 && Review.count >= 300
  puts ">> YA HAY DATOS: #{Book.count} libros, skip"
  exit
end
puts ">> SEED 100/200/300"
admin = User.where(email: "admin@bibliotk.cl").first_or_create! { |u| u.name="Admin"; u.password="123456"; u.role="admin" }
admin.update!(role: "admin", banned: false)

100.times { |i| Book.where(title: "Libro #{i+1}").first_or_create! { |b| b.author="Autor #{(i%20)+1}" } }
books = Book.all.to_a
200.times do |i|
  email="user#{i+1}@test.cl"
  User.where("lower(email)=?", email.downcase).first_or_create! { |u| u.name="User #{i+1}"; u.email=email; u.password="123456"; u.role="user"; u.banned=false }
end
users = User.where(role:"user").to_a
Review.delete_all
Book.update_all(valid_reviews_count:0, total_stars:0)
used=Set.new; c=0
while c<300
  b=books.sample; u=users.sample; k="#{u.id}-#{b.id}"
  next if used.include?(k)
  used.add(k)
  Review.create!(user_id:u.id, book_id:b.id, stars:rand(1..5), comment:"Auto #{c+1}")
  c+=1
end
Book.find_each { |b| ReconcileBookRatingJob.new.perform(b.id) }
File.write("tmp/data_generation_timing.txt","Timing guardado: #{Time.now}\n#{User.count} users, #{Book.count} books, #{Review.count} reviews\n")
puts ">> SEED OK"
