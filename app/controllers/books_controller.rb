class BooksController < ApplicationController
  def index
    @per_page = 50 # REQUERIMIENTO PDF HOMOLOGADO
    @page = [params[:page].to_i, 1].max
    @page = 1 if @page < 1

    @home_timing = Benchmark.realtime do
      @total_count = Book.count
      @total_pages = (@total_count.to_f / @per_page).ceil
      @total_pages = 1 if @total_pages == 0
      @page = @total_pages if @page > @total_pages
      offset = (@page - 1) * @per_page
      @books = Book.order(:id).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).limit(@per_page).offset(offset)
    end

    @data_gen_timing = nil
    timing_file = Rails.root.join("tmp/data_generation_timing.txt")
    @data_gen_timing = File.read(timing_file).strip if File.exist?(timing_file)

    @o1_benchmark = Benchmark.realtime do
      10.times { Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).map { |b| [b.title, b.average_rating] } }
    end
  end

  def show
    @book = Book.find(params[:id])
    @reviews_per_page = 20
    @reviews_page = [params[:reviews_page].to_i, 1].max
    @reviews_page = 1 if @reviews_page < 1
    total_reviews = @book.reviews.count
    @reviews_total_pages = (total_reviews.to_f / @reviews_per_page).ceil
    @reviews_total_pages = 1 if @reviews_total_pages == 0
    @reviews_page = @reviews_total_pages if @reviews_page > @reviews_total_pages
    offset = (@reviews_page - 1) * @reviews_per_page
    @reviews = @book.reviews.includes(:user).order(created_at: :desc).limit(@reviews_per_page).offset(offset)
    @reviews_total_count = total_reviews
    @my_review = @book.user_review(current_user) if current_user
  end
end
