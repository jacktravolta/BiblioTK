class BooksController < ApplicationController
  def index
    per_page = 50
    page = [(params[:page] || 1).to_i, 1].max
    home_t = Benchmark.realtime do
      @books = Book.select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).order(valid_reviews_count: :desc).limit(per_page).offset((page-1)*per_page).to_a
    end
    bench_t = Benchmark.realtime do
      10.times { Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).to_a.map(&:average_rating) }
    end
    @home_timing = home_t
    @o1_benchmark = bench_t
    @total_books = Book.count
    @total_pages = (@total_books.to_f / per_page).ceil
    @current_page = page
  end

  def show
    @book = Book.find(params[:id])
    @book.reconcile_valid_ratings!
    @book.reload
    # paginación de reviews que usa tu vista en linea 98
    @reviews_page = [(params[:reviews_page] || 1).to_i, 1].max
    per_page_r = 10
    base = @book.reviews.joins(:user).where(users: {banned: false})
    @reviews_total_pages = (base.count.to_f / per_page_r).ceil
    @reviews_total_pages = 1 if @reviews_total_pages == 0
    @reviews = base.order(created_at: :desc).limit(per_page_r).offset((@reviews_page-1)*per_page_r)
    @my_review = @book.reviews.find_by(user: current_user) if defined?(current_user) && current_user
    @review = @my_review || @book.reviews.new
  end
end
