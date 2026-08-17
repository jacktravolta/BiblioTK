class BooksController < ApplicationController
  def index
    per_page = 50
    page = [(params[:page] || 1).to_i, 1].max
    @books = Book.select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).order(valid_reviews_count: :desc, valid_total_stars: :desc, id: :desc).limit(per_page).offset((page-1)*per_page)
    @total_books = Book.count
    @total_pages = (@total_books.to_f / per_page).ceil
    @current_page = page
    @home_timing = 0
  end
  def show
    @book = Book.find(params[:id])
    @book.reconcile_valid_ratings! if @book.reviews.count != @book.valid_reviews_count
    @book.reload
    @review = @book.reviews.find_by(user_id: current_user&.id) || @book.reviews.new
    @reviews_page = [(params[:reviews_page] || 1).to_i, 1].max
    @reviews_per_page = 20
    @reviews_total = @book.valid_reviews_count
    @reviews_total_pages = (@reviews_total.to_f / @reviews_per_page).ceil
    @reviews_total_pages = 1 if @reviews_total_pages < 1
    @reviews = @book.reviews.joins(:user).where(users: {banned: false}).order(stars: :desc, created_at: :desc).limit(@reviews_per_page).offset((@reviews_page-1)*@reviews_per_page)
  end
end
