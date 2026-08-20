puts ">> AUTO SEED CHECK..."
require 'set'
seed_big = ENV['SEED_BIG'] == 'true'
puts ">> SEED_BIG=#{seed_big}"

# detecta columnas reales
book_cols = Book.column_names
review_cols = Review.column_names
puts ">> Book cols: #{book_cols}"
puts ">> Review cols: #{review_cols}"

# nombres correctos
stars_col = book_cols.include?("valid_total_stars") ? "valid_total_stars" : "total_stars"
count_col = book_cols.include?("valid_reviews_count") ? "valid_reviews_count" : "reviews_count"
content_col = review_cols.include?("content") ? :content : (review_cols.include?("body") ? :body : :comment)

target_books = 50
target_users = 7
target_reviews = seed_big ? 5000 : 0

if Book.count >= target_books && User.where(role:"user").count >= target_users && (!seed_big || Review.count >= target_reviews)
  puts ">> YA HAY DATOS - skip"
  exit
end

admin = User.where(email:"admin@bibliotk.cl").first_or_create! { |u| u.name="Admin"; u.password="123456"; u.role="admin" }
admin.update!(role:"admin", banned:false, password:"123456", password_confirmation:"123456")

7.times do |i|
  email="user#{i+1}@test.com"
  u = User.where("lower(email)=?", email.downcase).first_or_initialize
  u.name="User #{i+1}"; u.email=email; u.password="12345678"; u.password_confirmation="12345678"; u.role="user"; u.banned=false
  u.save!
end

50.times { |i| Book.where(title:"Libro #{i+1}").first_or_create! { |b| b.author="Autor #{(i%20)+1}" } }

if seed_big
  books=Book.all.to_a; users=User.where(role:"user").to_a
  Review.delete_all
  Book.update_all("#{count_col}=0, #{stars_col}=0") rescue nil
  used=Set.new; c=0
  while c < 5000
    b=books.sample; u=users.sample; k="#{u.id}-#{b.id}"; next if used.include?(k)
    used.add(k)
    attrs={user_id:u.id, book_id:b.id, stars:rand(1..5)}
    attrs[content_col]="Review #{c+1} auto BIG"
    Review.create!(attrs)
    c+=1
    puts ">> #{c}/5000" if c % 500 == 0
  end
  Book.find_each { |b| ReconcileBookRatingJob.new.perform(b.id) rescue nil }
end

puts ">> SEED OK #{Book.count} books, #{User.count} users, #{Review.count} reviews"
