class BooksController < ApplicationController
  def index
    require "benchmark"
    per_page = 50
    @q = params[:q].to_s.strip[0..100]
    @page = [(params[:page] || 1).to_i, 1].max
    @sort = params[:sort].to_s

    scope = Book.all
    if @q.present?
      pattern = "%#{@q.downcase}%"
      scope = scope.where("LOWER(title) LIKE ? OR LOWER(author) LIKE ?", pattern, pattern)
    end

    # Orden por mayor reseña - mantiene O(1) porque usa contadores materializados
    # No toca tabla reviews, solo books.valid_reviews_count
    if @sort == "rating"
      # Por mayor rating promedio
      scope = scope.order(Arel.sql("CASE WHEN valid_reviews_count >= 3 THEN (valid_total_stars::float / valid_reviews_count) ELSE 0 END DESC, valid_reviews_count DESC, id ASC"))
    else
      # DEFAULT: por mayor cantidad de reseñas (mayor reseña)
      scope = scope.order(valid_reviews_count: :desc, valid_total_stars: :desc, id: :asc)
    end

    @total_books = scope.count
    @total_pages = (@total_books.to_f / per_page).ceil
    @total_pages = 1 if @total_pages <= 0
    @page = @total_pages if @page > @total_pages

    @home_ms = Benchmark.realtime do
      @books = scope.select(:id, :title, :author, :valid_reviews_count, :valid_total_stars)
                    .limit(per_page)
                    .offset((@page-1)*per_page)
                    .to_a
    end
    @home_ms = (@home_ms * 1000).round(2)

    @home_10x_ms = Benchmark.realtime do
      10.times do
        Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).order(valid_reviews_count: :desc).map(&:average_rating)
      end
    end
    @home_10x_ms = (@home_10x_ms * 1000).round(2)
    @data_gen_timing = File.read("tmp/data_generation_timing.txt") rescue nil
  end

  def show
    @book = Book.find(params[:id])
    @my_review = current_user ? @book.reviews.find_by(user: current_user) : nil
    @review = @my_review || @book.reviews.new
    @reviews_page = [(params[:reviews_page] || 1).to_i, 1].max
    per_page_reviews = 10
    base = current_user&.admin? ? @book.reviews.includes(:user).order(created_at: :desc) : @book.reviews.joins(:user).where(users: { banned: false }).includes(:user).order(created_at: :desc)
    @reviews_total = base.count
    @reviews_total_pages = (@reviews_total.to_f / per_page_reviews).ceil
    @reviews_total_pages = 1 if @reviews_total_pages <= 0
    @reviews_page = @reviews_total_pages if @reviews_page > @reviews_total_pages
    @reviews = base.limit(per_page_reviews).offset((@reviews_page-1)*per_page_reviews)
  end
end
