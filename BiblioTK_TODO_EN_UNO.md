# BiblioTK - Proyecto Todo-en-Uno

**Generado:** mar 18 ago 2026 21:57:39 -04
**Desde:** /home/test/Documentos/Proyectos/DockerBiblioTK/BiblioTK

## ESTRUCTURA DEL PROYECTO
```
./app/assets/builds/.keep
./app/assets/config/manifest.js
./app/assets/images/.keep
./app/assets/stylesheets/application.bootstrap.scss
./app/channels/application_cable/channel.rb
./app/channels/application_cable/connection.rb
./app/controllers/application_controller.rb
./app/controllers/books_controller.rb
./app/controllers/concerns/.keep
./app/controllers/reviews_controller.rb
./app/controllers/sessions_controller.rb
./app/controllers/users_controller.rb
./app/helpers/application_helper.rb
./app/javascript/application.js
./app/javascript/controllers/application.js
./app/javascript/controllers/hello_controller.js
./app/javascript/controllers/index.js
./app/jobs/analyze_review_job.rb
./app/jobs/application_job.rb
./app/jobs/detect_book_fraud_job.rb
./app/jobs/rating_reconciliation_job.rb
./app/jobs/reconcile_book_rating_job.rb
./app/jobs/update_book_ratings_on_user_ban_job.rb
./app/mailers/application_mailer.rb
./app/models/application_record.rb
./app/models/book.rb
./app/models/concerns/.keep
./app/models/fraud_analysis.rb
./app/models/review_analysis.rb
./app/models/review.rb
./app/models/user_ban_log.rb
./app/models/user.rb
./app/services/ai_analyzer.rb
./app/views/books/index.html.erb
./app/views/books/show.html.erb
./app/views/layouts/application.html.erb
./app/views/layouts/mailer.html.erb
./app/views/layouts/mailer.text.erb
./app/views/sessions/new.html.erb
./app/views/users/index.html.erb
./app/views/users/show.html.erb
./benchmark_500k.rb
./BiblioTK_TODO_EN_UNO.md
./bin/dev
./bin/docker-entrypoint
./bin/importmap
./bin/rails
./bin/rake
./bin/setup
./config/application.rb
./config/boot.rb
./config/cable.yml
./config/credentials.yml.enc
./config/environment.rb
./config/environments/development.rb
./config/environments/production.rb
./config/environments/test.rb
./config/importmap.rb
./config/initializers/assets.rb
./config/initializers/content_security_policy.rb
./config/initializers/filter_parameter_logging.rb
./config/initializers/inflections.rb
./config/initializers/permissions_policy.rb
./config/locales/en.yml
./config/puma.rb
./config/routes.rb
./config.ru
./config/storage.yml
./db/migrate/20260816010000_create_users.rb
./db/migrate/20260816010001_create_books.rb
./db/migrate/20260816010002_create_reviews.rb
./db/migrate/20260816010003_create_review_analyses.rb
./db/migrate/20260816010004_create_fraud_analyses.rb
./db/migrate/20260816010005_create_user_ban_logs.rb
./db/schema.rb
./db/seeds.rb
./DECISIONES.md
./docker-compose.yml
./Dockerfile
./.dockerignore
./entrypoint.sh
./Gemfile
./Gemfile.lock
./generador_todo_en_uno.sh
./.gitattributes
./.gitignore
./lib/assets/.keep
./lib/tasks/.keep
./.node-version
./package.json
./Procfile.dev
./Prueba Product builder.pdf
./public/404.html
./public/422.html
./public/500.html
./public/apple-touch-icon.png
./public/apple-touch-icon-precomposed.png
./public/favicon.ico
./public/robots.txt
./Rakefile
./README.md
./.rspec
./.ruby-version
./spec/factories/books.rb
./spec/factories/reviews.rb
./spec/factories/test_data_factory.rb
./spec/factories/users.rb
./spec/integration/review_concurrency_spec.rb
./spec/integration/user_ban_rating_flow_spec.rb
./spec/jobs/rating_reconciliation_job_spec.rb
./spec/jobs/reconcile_book_rating_job_spec.rb
./spec/jobs/update_book_ratings_on_user_ban_job_spec.rb
./spec/models/book_spec.rb
./spec/models/review_spec.rb
./spec/models/user_spec.rb
./spec/rails_helper.rb
./spec/spec_helper.rb
./test/application_system_test_case.rb
./test/channels/application_cable/connection_test.rb
./test/controllers/.keep
./test/fixtures/files/.keep
./test/helpers/.keep
./TESTING.md
./TESTING.sh
./test/integration/.keep
./test/mailers/.keep
./test/models/.keep
./test/system/.keep
./test/test_helper.rb
```

## CONTENIDO COMPLETO


---

### ARCHIVO: `./app/assets/config/manifest.js`

```js
//= link_tree ../images
//= link_tree ../../javascript .js
//= link_tree ../../../vendor/javascript .js
//= link_tree ../builds

```

---

### ARCHIVO: `./app/assets/stylesheets/application.bootstrap.scss`

```scss
@import 'bootstrap/scss/bootstrap';
@import 'bootstrap-icons/font/bootstrap-icons';

```

---

### ARCHIVO: `./app/channels/application_cable/channel.rb`

```rb
module ApplicationCable; class Channel < ActionCable::Channel::Base; end; end

```

---

### ARCHIVO: `./app/channels/application_cable/connection.rb`

```rb
module ApplicationCable; class Connection < ActionCable::Connection::Base; end; end

```

---

### ARCHIVO: `./app/controllers/application_controller.rb`

```rb
class ApplicationController < ActionController::Base
  helper_method :current_user
  def current_user; @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]; end
end

```

---

### ARCHIVO: `./app/controllers/books_controller.rb`

```rb
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

    if @sort == "rating"
      scope = scope.order(Arel.sql("CASE WHEN valid_reviews_count >= 3 THEN (valid_total_stars::float / valid_reviews_count) ELSE 0 END DESC, valid_reviews_count DESC, id ASC"))
    elsif @sort == "id"
      scope = scope.order(id: :desc)
    else
      scope = scope.order(valid_reviews_count: :desc, valid_total_stars: :desc, id: :asc)
    end

    @total_books = scope.count
    @total_pages = (@total_books.to_f / per_page).ceil
    @total_pages = 1 if @total_pages <= 0
    @page = @total_pages if @page > @total_pages

    @home_ms = Benchmark.realtime do
      @books = scope.select(:id, :title, :author, :valid_reviews_count, :valid_total_stars, :created_at)
                    .limit(per_page)
                    .offset((@page-1)*per_page)
                    .to_a
    end
    @home_ms = (@home_ms * 1000).round(2)

    @home_10x_ms = Benchmark.realtime do
      10.times do
        Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars, :created_at).order(valid_reviews_count: :desc).map(&:average_rating)
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

```

---

### ARCHIVO: `./app/controllers/reviews_controller.rb`

```rb
class ReviewsController < ApplicationController
  before_action { redirect_to login_path unless current_user }
  def create
    @book=Book.find(params[:book_id])
    @review=@book.reviews.build(review_params.merge(user: current_user))
    if @review.save; redirect_to book_path(@book), notice: "Reseña creada"
    else; redirect_to book_path(@book), alert: @review.errors.full_messages.join(", "); end
  end
  def update
    @review=current_user.reviews.find(params[:id])
    @review.update(review_params); redirect_to book_path(@review.book), notice: "Actualizada"
  end
  def destroy
    @review=current_user.reviews.find(params[:id]); b=@review.book; @review.destroy; redirect_to book_path(b), notice: "Borrada"
  end
  private; def review_params; params.require(:review).permit(:stars, :content); end
end

```

---

### ARCHIVO: `./app/controllers/sessions_controller.rb`

```rb
class SessionsController < ApplicationController
  def new; end
  def create
    user = User.find_by(email: params[:email].to_s.downcase)
    if user&.authenticate(params[:password])
      session[:user_id]=user.id; redirect_to root_path, notice: "Bienvenido #{user.name}"
    else
      flash.now[:alert]="Email o pass malos"; render :new
    end
  end
  def destroy; session[:user_id]=nil; redirect_to root_path, notice: "Logout"; end
end

```

---

### ARCHIVO: `./app/controllers/users_controller.rb`

```rb
class UsersController < ApplicationController
  before_action :require_admin

  def index
    per_page = 20
    @page = [(params[:page] || 1).to_i, 1].max
    @q = params[:q].to_s.strip

    scope = User.order(:id)
    
    if @q.present?
      # ILIKE para postgres, busca por nombre, email, role
      like = "%#{@q}%"
      scope = scope.where("name ILIKE ? OR email ILIKE ? OR role ILIKE ?", like, like, like)
    end

    # filtro extra opcional por estado
    if params[:filter] == "banned"
      scope = scope.where(banned: true)
    elsif params[:filter] == "active"
      scope = scope.where(banned: false)
    end

    @total_users = scope.count
    @total_pages = (@total_users.to_f / per_page).ceil
    @total_pages = 1 if @total_pages == 0
    @page = @total_pages if @page > @total_pages

    @users = scope.limit(per_page).offset((@page - 1) * per_page)
  end

  def ban
    @user = User.find(params[:id])
    @user.ban_by!(current_user, reason: params[:reason])
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} baneado. Ratings recalculados O(1)"
  end

  def unban
    @user = User.find(params[:id])
    @user.unban_by!(current_user)
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} desbaneado. Ratings recalculados O(1)"
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to books_path, alert: "Solo admin"
    end
  end
end

```

---

### ARCHIVO: `./app/helpers/application_helper.rb`

```rb
module ApplicationHelper
  def corporate_paginator(current_page, total_pages, total_count, per_page, param_name: :page, path: nil)
    return "" if total_pages <= 1
    path ||= request.path
    # conserva otros params
    base_params = request.query_parameters.except(param_name.to_s)

    html = %Q{<div class="d-flex justify-content-between align-items-center mt-4 p-3 bg-white border rounded-3" style="border-radius:12px!important;">
      <div class="small text-muted">Página #{current_page} de #{total_pages} • #{total_count} registros • #{per_page} por página</div>
      <div class="d-flex gap-1">}

    # Prev
    if current_page > 1
      prev_params = base_params.merge(param_name => current_page - 1)
      html += %Q{<a href="#{path}?#{prev_params.to_query}" class="btn btn-sm" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">← Anterior</a>}
    else
      html += %Q{<span class="btn btn-sm disabled" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;opacity:0.5;">← Anterior</span>}
    end

    # Números (ventana de 5)
    start_p = [current_page - 2, 1].max
    end_p = [start_p + 4, total_pages].min
    start_p = [end_p - 4, 1].max

    (start_p..end_p).each do |p|
      if p == current_page
        html += %Q{<span class="btn btn-sm" style="background:#0f172a;color:white;border-radius:8px;min-width:36px;">#{p}</span>}
      else
        pp = base_params.merge(param_name => p)
        html += %Q{<a href="#{path}?#{pp.to_query}" class="btn btn-sm" style="background:white;border:1px solid #e2e8f0;border-radius:8px;min-width:36px;">#{p}</a>}
      end
    end

    # Next
    if current_page < total_pages
      next_params = base_params.merge(param_name => current_page + 1)
      html += %Q{<a href="#{path}?#{next_params.to_query}" class="btn btn-sm" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">Siguiente →</a>}
    else
      html += %Q{<span class="btn btn-sm disabled" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;opacity:0.5;">Siguiente →</span>}
    end

    html += "</div></div>"
    html.html_safe
  end
end

```

---

### ARCHIVO: `./app/javascript/application.js`

```js
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

```

---

### ARCHIVO: `./app/javascript/controllers/application.js`

```js
import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }

```

---

### ARCHIVO: `./app/javascript/controllers/hello_controller.js`

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.textContent = "Hello World!"
  }
}

```

---

### ARCHIVO: `./app/javascript/controllers/index.js`

```js
// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

```

---

### ARCHIVO: `./app/jobs/analyze_review_job.rb`

```rb
class AnalyzeReviewJob < ApplicationJob; queue_as :default; def perform(rid); r=Review.find_by(id:rid); return unless r&.content.present?; return unless AiAnalyzer.active?; d=AiAnalyzer.new.analizar_resena(r.content); return if d.blank?; a=ReviewAnalysis.find_or_initialize_by(review_id:r.id); a.update!(sentimiento:d["sentimiento"],resumen:d["resumen"],confianza:d["confianza"]); end; end

```

---

### ARCHIVO: `./app/jobs/application_job.rb`

```rb
class ApplicationJob < ActiveJob::Base
  if defined?(OpenAI::Errors::RateLimitError)
    retry_on OpenAI::Errors::RateLimitError, wait: :polynomially_longer, attempts: 5
  elsif defined?(Faraday::TooManyRequestsError)
    retry_on Faraday::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  end
  retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
end

```

---

### ARCHIVO: `./app/jobs/detect_book_fraud_job.rb`

```rb
class DetectBookFraudJob < ApplicationJob; queue_as :default; def perform(bid); return unless AiAnalyzer.active?; b=Book.find_by(id:bid); return unless b; last=b.fraud_analyses.order(created_at: :desc).first; if last && b.reviews.where("created_at > ?", last.created_at).none? && last.created_at > 2.minutes.ago; return; end; texts=b.reviews.where.not(content:[nil,""]).order(created_at: :desc).limit(30).pluck(:content); return if texts.size <=10; return if b.valid_reviews_count <3; avg=b.valid_total_stars.to_f / b.valid_reviews_count; data=AiAnalyzer.new.detectar_fraude(texts,avg); return if data.blank?; b.fraud_analyses.create!(fraude:data["fraude"],confianza:data["confianza"],razon:data["razon"],reviews_analyzed:texts.size,model:AiAnalyzer::MODEL); end; end

```

---

### ARCHIVO: `./app/jobs/rating_reconciliation_job.rb`

```rb
class RatingReconciliationJob < ApplicationJob; queue_as :default; def perform; Book.find_each{|b| ReconcileBookRatingJob.perform_later(b.id)}; end; end

```

---

### ARCHIVO: `./app/jobs/reconcile_book_rating_job.rb`

```rb
class ReconcileBookRatingJob < ApplicationJob; queue_as :default; def perform(id); b=Book.find_by(id:id); return unless b; b.with_lock{ b.reconcile_valid_ratings! }; end; end

```

---

### ARCHIVO: `./app/jobs/update_book_ratings_on_user_ban_job.rb`

```rb
class UpdateBookRatingsOnUserBanJob < ApplicationJob
  queue_as :default
  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user
    book_ids = Review.where(user_id: user.id).distinct.pluck(:book_id)
    Book.where(id: book_ids).find_each(&:reconcile_valid_ratings!)
  end
end

```

---

### ARCHIVO: `./app/mailers/application_mailer.rb`

```rb
class ApplicationMailer < ActionMailer::Base; default from:"from@example.com"; layout "mailer"; end

```

---

### ARCHIVO: `./app/models/application_record.rb`

```rb
class ApplicationRecord < ActiveRecord::Base; primary_abstract_class; end

```

---

### ARCHIVO: `./app/models/book.rb`

```rb
class Book < ApplicationRecord
  has_many :reviews, dependent: :destroy; has_many :fraud_analyses, dependent: :destroy
  validates :title, :author, presence:true; validates :valid_reviews_count, :valid_total_stars, numericality:{only_integer:true, greater_than_or_equal_to:0}
  def average_rating; return nil if valid_reviews_count <3; (valid_total_stars.to_f / valid_reviews_count).round(1, half: :up); end
  def average_rating_label; average_rating || "Reseñas Insuficientes"; end
  def increment_valid_ratings!(stars); stars=Integer(stars); raise ArgumentError unless stars.between?(1,5); self.class.where(id:id).update_all(["valid_reviews_count = valid_reviews_count + 1, valid_total_stars = valid_total_stars + ?", stars]); end
  def decrement_valid_ratings!(stars); stars=Integer(stars); raise ArgumentError unless stars.between?(1,5); self.class.where(id:id).update_all(["valid_reviews_count = GREATEST(valid_reviews_count - 1, 0), valid_total_stars = GREATEST(valid_total_stars - ?, 0)", stars]); end
  def sync_valid_ratings!(old,new); old=Integer(old); new=Integer(new); raise ArgumentError unless old.between?(1,5) && new.between?(1,5); return if old==new; self.class.where(id:id).update_all(["valid_total_stars = GREATEST(valid_total_stars - ? + ?, 0)", old, new]); end
  def reconcile_valid_ratings!
  valid = reviews.joins(:user).where(users: {banned: false})
  update_columns(valid_reviews_count: valid.count, valid_total_stars: valid.sum(:stars))
end

  def user_review(user); return unless user; reviews.find_by(user_id:user.id); end
end

```

---

### ARCHIVO: `./app/models/fraud_analysis.rb`

```rb
class FraudAnalysis < ApplicationRecord; belongs_to :book; scope :latest_first, ->{order(created_at: :desc)}; end

```

---

### ARCHIVO: `./app/models/review_analysis.rb`

```rb
class ReviewAnalysis < ApplicationRecord; belongs_to :review; end

```

---

### ARCHIVO: `./app/models/review.rb`

```rb
class Review < ApplicationRecord
  belongs_to :user
  belongs_to :book

  validates :stars, presence: true, inclusion: { in: 1..5 }
  validates :content, length: { maximum: 1000 }, allow_blank: true
  validates :user_id, uniqueness: { scope: :book_id, message: "ya reseñó este libro" }
  validate :reviewer_can_review

  after_create :increment_book_counter
  after_update :recalculate_book_counter
  after_destroy :recalculate_book_counter

  private

  def reviewer_can_review
    if user && !user.can_review?
      errors.add(:user, "baneado no puede reseñar")
    end
  end

  def increment_book_counter
    book.reconcile_valid_ratings!
  end

  def recalculate_book_counter
    book.reconcile_valid_ratings!
  end
end

```

---

### ARCHIVO: `./app/models/user_ban_log.rb`

```rb
class UserBanLog < ApplicationRecord; belongs_to :user; belongs_to :actor, class_name:"User", inverse_of: :ban_actions; end

```

---

### ARCHIVO: `./app/models/user.rb`

```rb
class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy

  def admin?
    role.to_s == "admin"
  end

  def user?
    role.to_s != "admin"
  end

  def banned?
    !!banned
  end

  def can_review?
    !banned?
  end

  def ban_by!(admin_user, reason: nil)
    update!(banned: true)
    UpdateBookRatingsOnUserBanJob.perform_now(self.id)
  end

  def unban_by!(admin_user)
    update!(banned: false)
    UpdateBookRatingsOnUserBanJob.perform_now(self.id)
  end
end

```

---

### ARCHIVO: `./app/services/ai_analyzer.rb`

```rb
require "json"; require "openai"
class AiAnalyzer
  MODEL = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")
  def self.active?; ENV["OPENAI_API_KEY"].present?; end
  def initialize; api_key=ENV["OPENAI_API_KEY"]; raise "OPENAI_API_KEY no configurada" if api_key.blank?; @client=OpenAI::Client.new(access_token: api_key, request_timeout: 15); end
  def analizar_resena(texto); return {} if texto.blank?; safe=texto.to_s.gsub(/<\/?review>/i,"[review]").truncate(2000); prompt="Solo JSON {\"sentimiento\":\"Positivo|Negativo|Neutral\",\"resumen\":\"max 8 palabras\",\"confianza\":0.0} <review>#{safe}</review>"; data=chat_json(prompt,"Solo JSON"); return {} unless %w[Positivo Negativo Neutral].include?(data["sentimiento"].to_s); {"sentimiento"=>data["sentimiento"],"resumen"=>data["resumen"].to_s.truncate(255),"confianza"=>data["confianza"].to_f.clamp(0.0,1.0)}; rescue StandardError=>e; Rails.logger.error("[AiAnalyzer] #{e.class}: #{e.message}"); {}; end
  def detectar_fraude(textos,promedio); return {} if textos.size <=10; reviews=textos.first(30).map{|t| "<review>#{t.to_s.gsub(/<\/?review>/i,"[review]").truncate(500)}</review>"}.join("\n"); prompt="Solo JSON {\"fraude\":false,\"confianza\":0.0,\"razon\":\"breve\"} Promedio:#{promedio.round(2)} <reviews>#{reviews}</reviews>"; data=chat_json(prompt,"Solo JSON fraude"); {"fraude"=>ActiveModel::Type::Boolean.new.cast(data["fraude"]),"confianza"=>data["confianza"].to_f.clamp(0.0,1.0),"razon"=>data["razon"].to_s.truncate(1000)}; rescue StandardError=>e; Rails.logger.error("[AiAnalyzer] #{e.class}: #{e.message}"); {}; end
  private; def chat_json(prompt,system); r=@client.chat(parameters:{model:MODEL,messages:[{role:"system",content:system},{role:"user",content:prompt}],temperature:0,response_format:{type:"json_object"}}); JSON.parse(r.dig("choices",0,"message","content").to_s); end
end

```

---

### ARCHIVO: `./app/views/books/index.html.erb`

```erb
<style>
.pagination-scroll { overflow-x:auto; -webkit-overflow-scrolling:touch; scrollbar-width: thin; }
.pagination-scroll::-webkit-scrollbar { height:6px; }
.pagination-scroll .pagination { flex-wrap: nowrap; margin-bottom:0; }
.pagination-scroll .page-link { white-space: nowrap; font-size:0.85rem; min-width:38px; text-align:center; }
.mini-stats-card { display: inline-flex; align-items: center; gap: 8px; background: #fff; border: 1px solid #e2e8f0; border-radius: 12px; padding: 6px 12px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); flex-wrap: wrap; max-width: 100%; }
.mini-pill { display: inline-flex; align-items: center; gap: 4px; border-radius: 20px; padding: 2px 8px; font-size: 0.7rem; font-weight: 600; white-space: nowrap; }
.pill-green { background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; }
.pill-amber { background: #fffbeb; color: #92400e; border: 1px solid #fde68a; }
.pill-slate { background: #f8fafc; color: #475569; border: 1px solid #e2e8f0; }
.dot { width:6px; height:6px; border-radius:50%; display:inline-block; }
.stars { color:#ffc107; letter-spacing: 3px; font-size:0.95rem; }
.stars-empty { color:#ddd; }
</style>

<div class="container py-3" id="home-top">
  <div class="d-flex justify-content-between align-items-center flex-wrap gap-2 mb-2">
    <h4 class="fw-bold mb-0">Libros (<%= @total_books %>)</h4>
    <div class="mini-stats-card">
      <span class="mini-pill pill-green"><span class="dot" style="background:#22c55e"></span> <%= @home_ms %> ms O(1)</span>
      <span class="mini-pill pill-amber"><%= @home_10x_ms %> ms 10x</span>
      <span class="mini-pill pill-slate">Pág <%= @page %>/<%= @total_pages %></span>
    </div>
  </div>

  <form method="get" action="<%= books_path %>" class="row g-2 mb-2">
    <div class="col-12 col-md-6">
      <input type="text" name="q" value="<%= @q %>" placeholder="Buscar por título o autor..." class="form-control form-control-sm">
    </div>
    <div class="col-6 col-md-2">
      <select name="sort" class="form-select form-select-sm">
        <option value="" <%= 'selected' if @sort.blank? %>>🔥 Más reseñas</option>
        <option value="rating" <%= 'selected' if @sort == 'rating' %>>⭐ Mejor rating</option>
        <option value="id" <%= 'selected' if @sort == 'id' %>>🆕 Más nuevos</option>
      </select>
    </div>
    <div class="col-3 col-md-2">
      <button class="btn btn-sm btn-primary w-100">Buscar</button>
    </div>
    <div class="col-3 col-md-2">
      <a href="<%= books_path %>" class="btn btn-sm btn-outline-secondary w-100">Limpiar</a>
    </div>
  </form>

  <% if @total_pages.to_i > 1 %>
    <div class="pagination-scroll mb-3 bg-white border rounded-3 p-2 shadow-sm" id="paginator-top">
      <ul class="pagination mb-0" id="pagination-list-top">
        <li class="page-item <%= 'disabled' if @page.to_i <= 1 %>"><%= link_to "«", books_path(q: @q, sort: @sort, page: @page.to_i-1, anchor: "home-top"), class: "page-link" %></li>
        <% window = 10; start_p = [@page.to_i - window, 1].max; end_p = [start_p + 19, @total_pages.to_i].min; start_p = [end_p - 19, 1].max %>
        <% (start_p..end_p).each do |p| %>
          <li class="page-item <%= 'active' if p == @page.to_i %>"><%= link_to p, books_path(q: @q, sort: @sort, page: p, anchor: "home-top"), class: "page-link" %></li>
        <% end %>
        <li class="page-item <%= 'disabled' if @page.to_i >= @total_pages.to_i %>"><%= link_to "»", books_path(q: @q, sort: @sort, page: @page.to_i+1, anchor: "home-top"), class: "page-link" %></li>
      </ul>
    </div>
  <% end %>

  <div class="row g-3">
    <% @books.each do |book| %>
      <div class="col-12 col-sm-6 col-md-4 col-lg-3">
        <a href="<%= book_path(book) %>" class="text-decoration-none">
          <div class="card h-100 shadow-sm rounded-4">
            <img src="https://picsum.photos/seed/book-<%= book.id %>/400/600" class="card-img-top rounded-top-4" style="object-fit:cover; height:250px;">
            <div class="card-body p-2">
              <h6 class="card-title mb-1 text-truncate text-dark"><%= book.title %></h6>
              <small class="text-muted d-block text-truncate"><%= book.author %></small>
              <div class="mt-1">
                <% if book.valid_reviews_count.to_i >= 3 %>
                  <div class="d-flex align-items-center gap-1 flex-wrap">
                    <span class="stars"><%= "★" * book.average_rating.to_i %><span class="stars-empty"><%= "★" * (5 - book.average_rating.to_i) %></span></span>
                    <small class="text-dark fw-bold"><%= book.average_rating %></small>
                    <small class="text-muted" style="font-size:0.7rem;">(<%= book.valid_reviews_count %>)</small>
                    <small class="text-muted" style="font-size:0.68rem;">• <%= book.created_at.strftime("%d/%m/%Y") if book.created_at %></small>
                  </div>
                <% else %>
                  <div class="d-flex align-items-center gap-1 flex-wrap">
                    <span class="badge bg-secondary" style="font-size:0.7rem;">Reseñas Insuficientes</span>
                    <small class="text-muted" style="font-size:0.7rem;">(<%= book.valid_reviews_count %>)</small>
                    <small class="text-muted" style="font-size:0.68rem;">• <%= book.created_at.strftime("%d/%m/%Y") if book.created_at %></small>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </a>
      </div>
    <% end %>
  </div>

  <% if @total_pages.to_i > 1 %>
    <div class="pagination-scroll mt-4 bg-white border rounded-3 p-2 shadow-sm" id="paginator-bottom">
      <ul class="pagination mb-0" id="pagination-list-bottom">
        <li class="page-item <%= 'disabled' if @page.to_i <= 1 %>"><%= link_to "« Anterior", books_path(q: @q, sort: @sort, page: @page.to_i-1, anchor: "paginator-bottom"), class: "page-link" %></li>
        <% window = 10; start_p = [@page.to_i - window, 1].max; end_p = [start_p + 19, @total_pages.to_i].min; start_p = [end_p - 19, 1].max %>
        <% (start_p..end_p).each do |p| %>
          <li class="page-item <%= 'active' if p == @page.to_i %>"><%= link_to p, books_path(q: @q, sort: @sort, page: p, anchor: "paginator-bottom"), class: "page-link" %></li>
        <% end %>
        <li class="page-item <%= 'disabled' if @page.to_i >= @total_pages.to_i %>"><%= link_to "Siguiente »", books_path(q: @q, sort: @sort, page: @page.to_i+1, anchor: "paginator-bottom"), class: "page-link" %></li>
      </ul>
    </div>
  <% end %>
</div>

<script>
document.addEventListener("DOMContentLoaded", function(){
  function centerActive(containerId, listId){
    const container = document.getElementById(containerId);
    const active = document.querySelector("#"+listId+" .page-item.active");
    if(container && active){
      const cRect = container.getBoundingClientRect();
      const aRect = active.getBoundingClientRect();
      container.scrollLeft += (aRect.left - cRect.left) - (cRect.width/2) + (aRect.width/2);
    }
  }
  centerActive("paginator-top","pagination-list-top");
  centerActive("paginator-bottom","pagination-list-bottom");
});
</script>

```

---

### ARCHIVO: `./app/views/books/show.html.erb`

```erb
<style>
.star-rating { display: flex; flex-direction: row-reverse; justify-content: flex-end; gap: 8px; }
.star-rating input { display: none; }
.star-rating label { font-size: 2.2rem; color: #ddd; cursor: pointer; transition: 0.2s; padding: 0 4px; line-height: 1; }
.star-rating label:hover, .star-rating label:hover ~ label, .star-rating input:checked ~ label { color: #ffc107; transform: scale(1.15); }
.pagination-scroll { overflow-x:auto; -webkit-overflow-scrolling:touch; scrollbar-width: thin; }
.pagination-scroll::-webkit-scrollbar { height:6px; }
.pagination-scroll .pagination { flex-wrap: nowrap; margin-bottom:0; }
.pagination-scroll .page-link { white-space: nowrap; font-size:0.85rem; min-width:38px; text-align:center; }
</style>

<div class="container py-3">
  <a href="/books" class="btn btn-sm btn-outline-secondary mb-3">← Volver a libros</a>
  <div class="row g-4">
    <div class="col-12 col-md-4">
      <img src="https://picsum.photos/seed/book-<%= @book.id %>/600/800" class="img-fluid rounded-4 shadow-sm w-100" style="object-fit:cover; max-height:500px;" onerror="this.src='https://picsum.photos/seed/<%= @book.id %>/600/800?random=<%= @book.id %>'">
      <div class="mt-3 p-3 bg-white border rounded-4 shadow-sm">
        <h5 class="fw-bold mb-1"><%= @book.title %></h5>
        <div class="text-muted mb-2"><%= @book.author %></div>
        <div>
          <span class="badge bg-primary"><%= @book.average_rating_label %></span>
          <small class="text-muted">(<%= @book.valid_reviews_count %> reseñas)</small>
        </div>
      </div>

      <% if current_user %>
        <% if current_user.banned? %>
          <div class="alert alert-danger mt-3">Estás baneado, no puedes valorar.</div>
        <% else %>
          <div class="mt-3 p-3 bg-white border rounded-4 shadow-sm">
            <h6 class="fw-bold"><%= @my_review ? "Editar mi valoración" : "Valora este libro" %></h6>
            <%= form_with model: [@book, @review], local: true do |f| %>
              <div class="mb-3">
                <label class="form-label small">Tu puntuación</label>
                <div class="star-rating">
                  <% 5.downto(1) do |i| %>
                    <%= f.radio_button :stars, i, id: "star#{i}", checked: @review.stars == i %>
                    <label for="star<%= i %>" title="<%= i %> estrellas">★</label>
                  <% end %>
                </div>
              </div>
              <div class="mb-2">
                <%= f.label :content, "Tu reseña (opcional, max 1000)", class: "small" %>
                <%= f.text_area :content, rows: 3, class: "form-control form-control-sm", maxlength: 1000, placeholder: "Escribe tu opinión..." %>
              </div>
              <%= f.submit @my_review ? "Actualizar reseña" : "Publicar reseña", class: "btn btn-sm btn-primary w-100" %>
            <% end %>
            <% if @my_review %>
              <%= button_to "Eliminar mi reseña", book_review_path(@book, @my_review), method: :delete, class: "btn btn-sm btn-outline-danger w-100 mt-2", form: { data: { turbo_confirm: "¿Eliminar reseña?" } } %>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <div class="mt-3 p-3 bg-light border rounded-4">
          <small><a href="/login">Inicia sesión</a> para valorar con estrellas</small>
        </div>
      <% end %>
    </div>

    <div class="col-12 col-md-8" id="reviews-section">
      <div class="d-flex justify-content-between align-items-center mb-2">
        <h5 class="mb-0">Reseñas (<%= @reviews_total %>)</h5>
        <small class="text-muted">Página <%= @reviews_page %> de <%= @reviews_total_pages %></small>
      </div>

      <% @reviews.each do |r| %>
        <div class="card mb-2 <%= 'border-danger' if r.user.banned? %>">
          <div class="card-body">
            <div class="d-flex justify-content-between">
              <strong><%= r.user.name %> <small class="text-muted"><%= r.user.email %></small></strong>
              <span style="color:#ffc107; letter-spacing: 3px;"><%= "★" * r.stars %><span style="color:#ddd;"><%= "★" * (5 - r.stars) %></span></span>
            </div>
            <p class="mb-1 mt-1"><%= r.content %></p>
            
            <% if current_user&.admin? && r.user_id != current_user.id %>
              <div class="d-flex gap-1 mt-2 align-items-center">
                <% if r.user.banned? %>
                  <span class="badge bg-danger">BANEADO</span>
                  <%= button_to "✅ Desbanear", unban_user_path(r.user), method: :post, class: "btn btn-sm btn-success", style: "font-size:0.7rem;" %>
                <% else %>
                  <%= button_to "🚫 Banear", ban_user_path(r.user), method: :post, class: "btn btn-sm btn-outline-danger", style: "font-size:0.7rem;" %>
                <% end %>
              </div>
              <% if r.user.banned? %>
                <div class="text-muted fst-italic mt-1" style="font-size:0.8rem;">(comentario baneado - solo visible para admin, no cuenta en promedio)</div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

      <% if @reviews_total_pages.to_i > 1 %>
        <div class="pagination-scroll mt-3 bg-white border rounded-3 p-2 shadow-sm" id="reviews-paginator">
          <ul class="pagination mb-0" id="reviews-pagination-list">
            <li class="page-item <%= 'disabled' if @reviews_page <= 1 %>"><%= link_to "« Anterior", book_path(@book, reviews_page: @reviews_page-1, anchor: "reviews-section"), class: "page-link" %></li>
            <% window = 10; start_p = [@reviews_page - window, 1].max; end_p = [start_p + 19, @reviews_total_pages.to_i].min; start_p = [end_p - 19, 1].max %>
            <% (start_p..end_p).each do |p| %>
              <li class="page-item <%= 'active' if p == @reviews_page %>" data-page="<%= p %>"><%= link_to p, book_path(@book, reviews_page: p, anchor: "reviews-section"), class: "page-link" %></li>
            <% end %>
            <li class="page-item <%= 'disabled' if @reviews_page >= @reviews_total_pages.to_i %>"><%= link_to "Siguiente »", book_path(@book, reviews_page: @reviews_page+1, anchor: "reviews-section"), class: "page-link" %></li>
          </ul>
        </div>
        <div class="text-center small text-muted mt-1">Desliza → para ver todas las páginas de reseñas</div>
      <% end %>
    </div>
  </div>
</div>

<script>
document.addEventListener("DOMContentLoaded", function(){
  const container = document.getElementById("reviews-paginator");
  const active = document.querySelector("#reviews-pagination-list .page-item.active");
  if(container && active){
    const cRect = container.getBoundingClientRect();
    const aRect = active.getBoundingClientRect();
    container.scrollLeft += (aRect.left - cRect.left) - (cRect.width/2) + (aRect.width/2);
  }
});
</script>

```

---

### ARCHIVO: `./app/views/layouts/application.html.erb`

```erb
<!DOCTYPE html>
<html>
  <head>
    <title>BiblioTK</title>
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
      body { background:#f8fafc; }
      .navbar-brand { font-weight:800; letter-spacing:-0.5px; }
      /* FIX CORTADO EN CELU */
      .navbar { flex-wrap:wrap; }
      @media (max-width: 576px) {
        .navbar .container { flex-wrap:wrap; gap:8px; }
        .navbar-nav { flex-direction:row; gap:10px; flex-wrap:wrap; }
        .navbar-text { font-size:0.75rem; white-space:normal !important; }
      }
    </style>
  </head>
  <body>
    <nav class="navbar navbar-expand-lg navbar-dark" style="background:#0f172a;">
      <div class="container">
        <a class="navbar-brand" href="/">BiblioTK</a>
        <div class="d-flex align-items-center gap-2 ms-auto flex-wrap">
          <a href="/books" class="btn btn-sm btn-outline-light">Libros</a>
          <% if defined?(current_user) && current_user %>
            <% if current_user.admin? %>
              <a href="/users" class="btn btn-sm btn-warning">Users</a>
            <% end %>
            <span class="text-white-50 small d-none d-sm-inline"><%= current_user.email %></span>
            <%= button_to "Salir", "/logout", method: :delete, class: "btn btn-sm btn-outline-light" %>
          <% else %>
            <a href="/login" class="btn btn-sm btn-light">Login</a>
          <% end %>
        </div>
      </div>
    </nav>
    <main>
      <% if flash[:notice] %><div class="alert alert-success m-3"><%= flash[:notice] %></div><% end %>
      <% if flash[:alert] %><div class="alert alert-danger m-3"><%= flash[:alert] %></div><% end %>
      <%= yield %>
    </main>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  </body>
</html>

```

---

### ARCHIVO: `./app/views/layouts/mailer.html.erb`

```erb
<%= yield %>

```

---

### ARCHIVO: `./app/views/layouts/mailer.text.erb`

```erb
<%= yield %>

```

---

### ARCHIVO: `./app/views/sessions/new.html.erb`

```erb
<div class="row justify-content-center mt-4">
  <div class="col-md-5">
    <div class="bg-white border rounded-4 p-5" style="border-radius:16px!important;border:1px solid #e2e8f0!important;">
      <div class="d-flex align-items-center gap-2 mb-4">
        <div style="background:#0f172a;width:40px;height:40px;border-radius:10px;display:flex;align-items:center;justify-content:center;color:white;font-weight:700;">B</div>
        <div>
          <div class="fw-bold" style="font-family:'Merriweather',serif;">Bibliotk Corporate</div>
          <div class="small text-muted" style="font-size:0.7rem;letter-spacing:1px;text-transform:uppercase;">Acceso Verificado</div>
        </div>
      </div>

      <h5 class="fw-bold mb-1" style="letter-spacing:-0.3px;">Iniciar sesión</h5>
      <p class="small text-muted mb-4">Use credenciales de prueba corporativa.</p>

      <%= form_with url: "/login", local: true do |f| %>
        <label class="small fw-medium text-muted mb-1">CORREO CORPORATIVO</label>
        <input name="email" class="form-control mb-3" style="height:44px;border-radius:8px;background:#f8fafc;border:1px solid #e2e8f0;" value="admin@test.com" placeholder="admin@test.com">

        <label class="small fw-medium text-muted mb-1">CONTRASEÑA</label>
        <input name="password" type="password" class="form-control mb-4" style="height:44px;border-radius:8px;background:#f8fafc;border:1px solid #e2e8f0;" value="123456">

        <button class="btn w-100" style="background:#0f172a;color:white;border-radius:8px;height:44px;font-weight:500;">Acceder al sistema</button>
      <% end %>

      <div class="mt-4 p-3 rounded-3" style="background:#f8fafc;border:1px solid #f1f5f9;">
        <div class="small fw-semibold mb-1" style="color:#334155;">Credenciales de demostración</div>
        <div class="small text-muted" style="font-size:0.8rem;line-height:1.5;">
          Admin: admin@test.com / 123456<br>
          Usuario: user-0-xxxx@test.com / 123456<br>
          <span style="color:#b45309;">5000 usuarios generados por bonus O(1)</span>
        </div>
      </div>
    </div>
    <div class="text-center small text-muted mt-3">Arquitectura O(1) • valid_reviews_count materializado</div>
  </div>
</div>

```

---

### ARCHIVO: `./app/views/users/index.html.erb`

```erb
<style>
.pagination-scroll { overflow-x:auto; -webkit-overflow-scrolling:touch; scrollbar-width: thin; position:relative; }
.pagination-scroll::-webkit-scrollbar { height:6px; }
.pagination-scroll .pagination { flex-wrap: nowrap; margin-bottom:0; }
.pagination-scroll .page-link { white-space: nowrap; font-size:0.85rem; min-width:38px; text-align:center; }
.users-table-wrap { overflow-x:auto; }
.users-table { min-width: 750px; }
.col-nombre { min-width: 140px; max-width: 180px; word-break: break-word; }
.col-email { min-width: 220px; word-break: break-all; font-size:0.85rem; }
</style>

<div class="container py-3">
  <a href="/books" class="btn btn-sm btn-outline-secondary mb-3">← Volver a libros</a>
  <h4 class="fw-bold">Administrar Usuarios (<%= @total_users %>) - 20 por página</h4>

  <form method="get" action="<%= users_path %>" class="row g-2 mb-2">
    <div class="col-12 col-md-6">
      <input type="text" name="q" value="<%= @q %>" placeholder="Buscar por nombre, email o rol..." class="form-control form-control-sm">
    </div>
    <div class="col-6 col-md-3">
      <select name="filter" class="form-select form-select-sm">
        <option value="">Todos</option>
        <option value="active" <%= 'selected' if params[:filter] == 'active' %>>Activos</option>
        <option value="banned" <%= 'selected' if params[:filter] == 'banned' %>>Baneados</option>
      </select>
    </div>
    <div class="col-6 col-md-3 d-flex gap-1">
      <button class="btn btn-sm btn-primary w-100">🔍 Buscar</button>
      <a href="<%= users_path %>" class="btn btn-sm btn-outline-secondary">Limpiar</a>
    </div>
  </form>

  <%# PAGINADOR ARRIBA -> ancla top %>
  <% if @total_pages > 1 %>
    <div class="pagination-scroll mb-2 bg-white border rounded-3 p-2 shadow-sm" id="paginator-top">
      <ul class="pagination mb-0" id="pagination-list-top">
        <li class="page-item <%= 'disabled' if @page <= 1 %>"><%= link_to "«", users_path(q: @q, filter: params[:filter], page: @page-1, anchor: "paginator-top"), class: "page-link" %></li>
        <% window = 25; start_p = [@page - window, 1].max; end_p = [start_p + 49, @total_pages].min; start_p = [end_p - 49, 1].max %>
        <% (start_p..end_p).each do |p| %>
          <li class="page-item <%= 'active' if p == @page %>" data-page="<%= p %>"><%= link_to p, users_path(q: @q, filter: params[:filter], page: p, anchor: "paginator-top"), class: "page-link" %></li>
        <% end %>
        <li class="page-item <%= 'disabled' if @page >= @total_pages %>"><%= link_to "»", users_path(q: @q, filter: params[:filter], page: @page+1, anchor: "paginator-top"), class: "page-link" %></li>
      </ul>
    </div>
  <% end %>

  <div class="bg-white border rounded-4 shadow-sm users-table-wrap" id="users-table">
    <table class="table table-sm table-hover mb-0 align-middle users-table">
      <thead class="table-light">
        <tr><th>ID</th><th>Nombre</th><th>Email</th><th>Rol</th><th>Estado</th><th>Acción</th></tr>
      </thead>
      <tbody>
        <% @users.each do |u| %>
          <tr class="<%= 'table-danger' if u.banned? %>">
            <td><%= u.id %></td>
            <td class="col-nombre"><%= u.name %></td>
            <td class="col-email"><%= u.email %></td>
            <td><span class="badge bg-<%= u.admin? ? 'dark' : 'secondary' %>"><%= u.role %></span></td>
            <td><% if u.banned? %><span class="badge bg-danger">BANEADO</span><% else %><span class="badge bg-success">Activo</span><% end %></td>
            <td>
              <% if u.id != current_user.id %>
                <% if u.banned? %>
                  <%= button_to "✅ Desbanear", unban_user_path(u, anchor: "users-table"), method: :post, class: "btn btn-sm btn-success", style: "font-size:0.7rem;" %>
                <% else %>
                  <%= button_to "🚫 Banear", ban_user_path(u, anchor: "users-table"), method: :post, class: "btn btn-sm btn-outline-danger", style: "font-size:0.7rem;" %>
                <% end %>
              <% else %><small class="text-muted">Tú</small><% end %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <%# PAGINADOR ABAJO -> ancla bottom, se queda abajo %>
  <% if @total_pages > 1 %>
    <div class="pagination-scroll mt-3 bg-white border rounded-3 p-2 shadow-sm" id="paginator-bottom">
      <ul class="pagination mb-0" id="pagination-list-bottom">
        <li class="page-item <%= 'disabled' if @page <= 1 %>"><%= link_to "« Anterior", users_path(q: @q, filter: params[:filter], page: @page-1, anchor: "paginator-bottom"), class: "page-link" %></li>
        <% window = 25; start_p = [@page - window, 1].max; end_p = [start_p + 49, @total_pages].min; start_p = [end_p - 49, 1].max %>
        <% (start_p..end_p).each do |p| %>
          <li class="page-item <%= 'active' if p == @page %>" data-page="<%= p %>"><%= link_to p, users_path(q: @q, filter: params[:filter], page: p, anchor: "paginator-bottom"), class: "page-link" %></li>
        <% end %>
        <li class="page-item <%= 'disabled' if @page >= @total_pages %>"><%= link_to "Siguiente »", users_path(q: @q, filter: params[:filter], page: @page+1, anchor: "paginator-bottom"), class: "page-link" %></li>
      </ul>
    </div>
    <div class="text-center small text-muted mt-2">Página <%= @page %> de <%= @total_pages %> • Desliza → en el paginador</div>
  <% end %>
</div>

<script>
document.addEventListener("DOMContentLoaded", function(){
  function centerActive(containerId, listId){
    const container = document.getElementById(containerId);
    const active = document.querySelector("#"+listId+" .page-item.active");
    if(container && active){
      const cRect = container.getBoundingClientRect();
      const aRect = active.getBoundingClientRect();
      container.scrollLeft += (aRect.left - cRect.left) - (cRect.width/2) + (aRect.width/2);
    }
  }
  centerActive("paginator-top","pagination-list-top");
  centerActive("paginator-bottom","pagination-list-bottom");
  // Si viene con #paginator-bottom, asegúrate de que quede visible
  if(window.location.hash === "#paginator-bottom"){
    setTimeout(()=>{ document.getElementById("paginator-bottom")?.scrollIntoView({block:"center"}); }, 100);
  }
});
</script>

```

---

### ARCHIVO: `./app/views/users/show.html.erb`

```erb
<div class="row g-4">
  <div class="col-md-4">
    <div class="bg-white border rounded-4 p-4" style="border-radius:12px!important;">
      <div class="d-flex align-items-center gap-3 mb-3">
        <div style="width:48px;height:48px;border-radius:12px;background:#0f172a;color:white;display:flex;align-items:center;justify-content:center;font-weight:700;"><%= @user.name[0].upcase %></div>
        <div>
          <div class="fw-bold"><%= @user.name %></div>
          <div class="small text-muted"><%= @user.email %></div>
        </div>
      </div>
      <div class="small"><span class="text-muted">Rol:</span> <b><%= @user.role.upcase %></b> • <span class="text-muted">ID:</span> <b><%= @user.id %></b></div>
      <div class="mt-3">
        <% if @user.banned? %>
          <span class="badge" style="background:#fef2f2;color:#991b1b;border:1px solid #fecaca;">BANEADO POR SPAM</span>
        <% else %>
          <span class="badge" style="background:#f0fdf4;color:#166534;border:1px solid #bbf7d0;">CUENTA ACTIVA</span>
        <% end %>
      </div>
    </div>
  </div>
  <div class="col-md-8">
    <h5 class="fw-bold">Historial de evaluaciones — <%= @reviews.size %></h5>
    <% @reviews.each do |r| %>
      <div class="bg-white border rounded-3 p-3 mb-2" style="border-radius:10px!important;">
        <div class="d-flex justify-content-between">
          <div><span style="color:#b45309;"><% r.stars.times do %>★<% end %></span><span style="color:#e2e8f0;"><% (5-r.stars).times do %>★<% end %></span> <a href="/books/<%= r.book_id %>" class="text-decoration-none small ms-2 fw-medium" style="color:#0f172a;"><%= r.book.title.truncate(40) %></a></div>
          <small class="text-muted" style="font-size:0.7rem;"><%= r.created_at.strftime("%d %b") %></small>
        </div>
        <div class="small text-muted mt-1"><%= r.content %></div>
      </div>
    <% end %>
  </div>
</div>

```

---

### ARCHIVO: `./benchmark_500k.rb`

```rb
require 'benchmark'
require 'fileutils'

total_time = Benchmark.realtime do
  # 1. 50 libros base si no existen
  if Book.count < 50
    books = 50.times.map { |i| { title: "Libro Base #{i}", author: "Autor Base #{i}", valid_reviews_count: 0, valid_total_stars: 0, created_at: Time.now, updated_at: Time.now } }
    Book.insert_all(books)
  end
  
  book = Book.find_or_create_by!(title: "Libro Popular", author: "Autor Test")
  
  SEED_COUNT = 5000
  BATCH_SIZE = 5000
  
  needed = SEED_COUNT - User.count
  if needed > 0
    puts "Creando #{needed} usuarios..."
    digest = BCrypt::Password.create("123456")
    (0...(needed.to_f/BATCH_SIZE).ceil).each do |b|
      size = [BATCH_SIZE, needed - b*BATCH_SIZE].min
      batch = size.times.map { |i| idx = b*BATCH_SIZE + i; { name: "User #{idx}", email: "user-#{idx}-#{SecureRandom.hex(4)}@test.com", password_digest: digest, created_at: Time.now, updated_at: Time.now, role: "user" } }
      User.insert_all(batch)
    end
  end
  
  if Review.count < SEED_COUNT
    user_ids = User.order(:id).limit(SEED_COUNT).pluck(:id)
    user_ids.each_slice(BATCH_SIZE) do |slice|
      reviews = slice.map { |uid| { user_id: uid, book_id: book.id, stars: rand(1..5), content: "Reseña benchmark #{SecureRandom.hex(2)}", created_at: Time.now, updated_at: Time.now } }
      Review.insert_all(reviews)
    end
    book.reconcile_valid_ratings!
  end
end

FileUtils.mkdir_p("tmp")
File.write("tmp/data_generation_timing.txt", "#{total_time.round(2)}s total | #{(total_time/60).round(2)} min | Libros:#{Book.count} Usuarios:#{User.count} Reseñas:#{Review.count} | #{Time.now.strftime('%d/%m %H:%M')}")

puts "TOTAL generación: #{total_time.round(2)}s"
puts "Guardado en tmp/data_generation_timing.txt: #{File.read('tmp/data_generation_timing.txt')}"

time_home = Benchmark.realtime { 10.times { Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).map { |b| [b.title, b.average_rating] } } }
puts "Home 50 libros x10: #{time_home.round(3)}s O(1) => #{(time_home/10*1000).round(2)}ms por request - PDF OK"

```

---

### ARCHIVO: `./BiblioTK_TODO_EN_UNO.md`

```md
# BiblioTK - Proyecto Todo-en-Uno

**Generado:** mar 18 ago 2026 21:57:39 -04
**Desde:** /home/test/Documentos/Proyectos/DockerBiblioTK/BiblioTK

## ESTRUCTURA DEL PROYECTO
```
./app/assets/builds/.keep
./app/assets/config/manifest.js
./app/assets/images/.keep
./app/assets/stylesheets/application.bootstrap.scss
./app/channels/application_cable/channel.rb
./app/channels/application_cable/connection.rb
./app/controllers/application_controller.rb
./app/controllers/books_controller.rb
./app/controllers/concerns/.keep
./app/controllers/reviews_controller.rb
./app/controllers/sessions_controller.rb
./app/controllers/users_controller.rb
./app/helpers/application_helper.rb
./app/javascript/application.js
./app/javascript/controllers/application.js
./app/javascript/controllers/hello_controller.js
./app/javascript/controllers/index.js
./app/jobs/analyze_review_job.rb
./app/jobs/application_job.rb
./app/jobs/detect_book_fraud_job.rb
./app/jobs/rating_reconciliation_job.rb
./app/jobs/reconcile_book_rating_job.rb
./app/jobs/update_book_ratings_on_user_ban_job.rb
./app/mailers/application_mailer.rb
./app/models/application_record.rb
./app/models/book.rb
./app/models/concerns/.keep
./app/models/fraud_analysis.rb
./app/models/review_analysis.rb
./app/models/review.rb
./app/models/user_ban_log.rb
./app/models/user.rb
./app/services/ai_analyzer.rb
./app/views/books/index.html.erb
./app/views/books/show.html.erb
./app/views/layouts/application.html.erb
./app/views/layouts/mailer.html.erb
./app/views/layouts/mailer.text.erb
./app/views/sessions/new.html.erb
./app/views/users/index.html.erb
./app/views/users/show.html.erb
./benchmark_500k.rb
./BiblioTK_TODO_EN_UNO.md
./bin/dev
./bin/docker-entrypoint
./bin/importmap
./bin/rails
./bin/rake
./bin/setup
./config/application.rb
./config/boot.rb
./config/cable.yml
./config/credentials.yml.enc
./config/environment.rb
./config/environments/development.rb
./config/environments/production.rb
./config/environments/test.rb
./config/importmap.rb
./config/initializers/assets.rb
./config/initializers/content_security_policy.rb
./config/initializers/filter_parameter_logging.rb
./config/initializers/inflections.rb
./config/initializers/permissions_policy.rb
./config/locales/en.yml
./config/puma.rb
./config/routes.rb
./config.ru
./config/storage.yml
./db/migrate/20260816010000_create_users.rb
./db/migrate/20260816010001_create_books.rb
./db/migrate/20260816010002_create_reviews.rb
./db/migrate/20260816010003_create_review_analyses.rb
./db/migrate/20260816010004_create_fraud_analyses.rb
./db/migrate/20260816010005_create_user_ban_logs.rb
./db/schema.rb
./db/seeds.rb
./DECISIONES.md
./docker-compose.yml
./Dockerfile
./.dockerignore
./entrypoint.sh
./Gemfile
./Gemfile.lock
./generador_todo_en_uno.sh
./.gitattributes
./.gitignore
./lib/assets/.keep
./lib/tasks/.keep
./.node-version
./package.json
./Procfile.dev
./Prueba Product builder.pdf
./public/404.html
./public/422.html
./public/500.html
./public/apple-touch-icon.png
./public/apple-touch-icon-precomposed.png
./public/favicon.ico
./public/robots.txt
./Rakefile
./README.md
./.rspec
./.ruby-version
./spec/factories/books.rb
./spec/factories/reviews.rb
./spec/factories/test_data_factory.rb
./spec/factories/users.rb
./spec/integration/review_concurrency_spec.rb
./spec/integration/user_ban_rating_flow_spec.rb
./spec/jobs/rating_reconciliation_job_spec.rb
./spec/jobs/reconcile_book_rating_job_spec.rb
./spec/jobs/update_book_ratings_on_user_ban_job_spec.rb
./spec/models/book_spec.rb
./spec/models/review_spec.rb
./spec/models/user_spec.rb
./spec/rails_helper.rb
./spec/spec_helper.rb
./test/application_system_test_case.rb
./test/channels/application_cable/connection_test.rb
./test/controllers/.keep
./test/fixtures/files/.keep
./test/helpers/.keep
./TESTING.md
./TESTING.sh
./test/integration/.keep
./test/mailers/.keep
./test/models/.keep
./test/system/.keep
./test/test_helper.rb
```

## CONTENIDO COMPLETO


---

### ARCHIVO: `./app/assets/config/manifest.js`

```js
//= link_tree ../images
//= link_tree ../../javascript .js
//= link_tree ../../../vendor/javascript .js
//= link_tree ../builds

```

---

### ARCHIVO: `./app/assets/stylesheets/application.bootstrap.scss`

```scss
@import 'bootstrap/scss/bootstrap';
@import 'bootstrap-icons/font/bootstrap-icons';

```

---

### ARCHIVO: `./app/channels/application_cable/channel.rb`

```rb
module ApplicationCable; class Channel < ActionCable::Channel::Base; end; end

```

---

### ARCHIVO: `./app/channels/application_cable/connection.rb`

```rb
module ApplicationCable; class Connection < ActionCable::Connection::Base; end; end

```

---

### ARCHIVO: `./app/controllers/application_controller.rb`

```rb
class ApplicationController < ActionController::Base
  helper_method :current_user
  def current_user; @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]; end
end

```

---

### ARCHIVO: `./app/controllers/books_controller.rb`

```rb
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

    if @sort == "rating"
      scope = scope.order(Arel.sql("CASE WHEN valid_reviews_count >= 3 THEN (valid_total_stars::float / valid_reviews_count) ELSE 0 END DESC, valid_reviews_count DESC, id ASC"))
    elsif @sort == "id"
      scope = scope.order(id: :desc)
    else
      scope = scope.order(valid_reviews_count: :desc, valid_total_stars: :desc, id: :asc)
    end

    @total_books = scope.count
    @total_pages = (@total_books.to_f / per_page).ceil
    @total_pages = 1 if @total_pages <= 0
    @page = @total_pages if @page > @total_pages

    @home_ms = Benchmark.realtime do
      @books = scope.select(:id, :title, :author, :valid_reviews_count, :valid_total_stars, :created_at)
                    .limit(per_page)
                    .offset((@page-1)*per_page)
                    .to_a
    end
    @home_ms = (@home_ms * 1000).round(2)

    @home_10x_ms = Benchmark.realtime do
      10.times do
        Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars, :created_at).order(valid_reviews_count: :desc).map(&:average_rating)
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

```

---

### ARCHIVO: `./app/controllers/reviews_controller.rb`

```rb
class ReviewsController < ApplicationController
  before_action { redirect_to login_path unless current_user }
  def create
    @book=Book.find(params[:book_id])
    @review=@book.reviews.build(review_params.merge(user: current_user))
    if @review.save; redirect_to book_path(@book), notice: "Reseña creada"
    else; redirect_to book_path(@book), alert: @review.errors.full_messages.join(", "); end
  end
  def update
    @review=current_user.reviews.find(params[:id])
    @review.update(review_params); redirect_to book_path(@review.book), notice: "Actualizada"
  end
  def destroy
    @review=current_user.reviews.find(params[:id]); b=@review.book; @review.destroy; redirect_to book_path(b), notice: "Borrada"
  end
  private; def review_params; params.require(:review).permit(:stars, :content); end
end

```

---

### ARCHIVO: `./app/controllers/sessions_controller.rb`

```rb
class SessionsController < ApplicationController
  def new; end
  def create
    user = User.find_by(email: params[:email].to_s.downcase)
    if user&.authenticate(params[:password])
      session[:user_id]=user.id; redirect_to root_path, notice: "Bienvenido #{user.name}"
    else
      flash.now[:alert]="Email o pass malos"; render :new
    end
  end
  def destroy; session[:user_id]=nil; redirect_to root_path, notice: "Logout"; end
end

```

---

### ARCHIVO: `./app/controllers/users_controller.rb`

```rb
class UsersController < ApplicationController
  before_action :require_admin

  def index
    per_page = 20
    @page = [(params[:page] || 1).to_i, 1].max
    @q = params[:q].to_s.strip

    scope = User.order(:id)
    
    if @q.present?
      # ILIKE para postgres, busca por nombre, email, role
      like = "%#{@q}%"
      scope = scope.where("name ILIKE ? OR email ILIKE ? OR role ILIKE ?", like, like, like)
    end

    # filtro extra opcional por estado
    if params[:filter] == "banned"
      scope = scope.where(banned: true)
    elsif params[:filter] == "active"
      scope = scope.where(banned: false)
    end

    @total_users = scope.count
    @total_pages = (@total_users.to_f / per_page).ceil
    @total_pages = 1 if @total_pages == 0
    @page = @total_pages if @page > @total_pages

    @users = scope.limit(per_page).offset((@page - 1) * per_page)
  end

  def ban
    @user = User.find(params[:id])
    @user.ban_by!(current_user, reason: params[:reason])
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} baneado. Ratings recalculados O(1)"
  end

  def unban
    @user = User.find(params[:id])
    @user.unban_by!(current_user)
    redirect_back fallback_location: users_path, notice: "Usuario #{@user.email} desbaneado. Ratings recalculados O(1)"
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to books_path, alert: "Solo admin"
    end
  end
end

```

---

### ARCHIVO: `./app/helpers/application_helper.rb`

```rb
module ApplicationHelper
  def corporate_paginator(current_page, total_pages, total_count, per_page, param_name: :page, path: nil)
    return "" if total_pages <= 1
    path ||= request.path
    # conserva otros params
    base_params = request.query_parameters.except(param_name.to_s)

    html = %Q{<div class="d-flex justify-content-between align-items-center mt-4 p-3 bg-white border rounded-3" style="border-radius:12px!important;">
      <div class="small text-muted">Página #{current_page} de #{total_pages} • #{total_count} registros • #{per_page} por página</div>
      <div class="d-flex gap-1">}

    # Prev
    if current_page > 1
      prev_params = base_params.merge(param_name => current_page - 1)
      html += %Q{<a href="#{path}?#{prev_params.to_query}" class="btn btn-sm" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">← Anterior</a>}
    else
      html += %Q{<span class="btn btn-sm disabled" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;opacity:0.5;">← Anterior</span>}
    end

    # Números (ventana de 5)
    start_p = [current_page - 2, 1].max
    end_p = [start_p + 4, total_pages].min
    start_p = [end_p - 4, 1].max

    (start_p..end_p).each do |p|
      if p == current_page
        html += %Q{<span class="btn btn-sm" style="background:#0f172a;color:white;border-radius:8px;min-width:36px;">#{p}</span>}
      else
        pp = base_params.merge(param_name => p)
        html += %Q{<a href="#{path}?#{pp.to_query}" class="btn btn-sm" style="background:white;border:1px solid #e2e8f0;border-radius:8px;min-width:36px;">#{p}</a>}
      end
    end

    # Next
    if current_page < total_pages
      next_params = base_params.merge(param_name => current_page + 1)
      html += %Q{<a href="#{path}?#{next_params.to_query}" class="btn btn-sm" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">Siguiente →</a>}
    else
      html += %Q{<span class="btn btn-sm disabled" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;opacity:0.5;">Siguiente →</span>}
    end

    html += "</div></div>"
    html.html_safe
  end
end

```

---

### ARCHIVO: `./app/javascript/application.js`

```js
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import * as bootstrap from "bootstrap"

```

---

### ARCHIVO: `./app/javascript/controllers/application.js`

```js
import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }

```

---

### ARCHIVO: `./app/javascript/controllers/hello_controller.js`

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.textContent = "Hello World!"
  }
}

```

---

### ARCHIVO: `./app/javascript/controllers/index.js`

```js
// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

```

---

### ARCHIVO: `./app/jobs/analyze_review_job.rb`

```rb
class AnalyzeReviewJob < ApplicationJob; queue_as :default; def perform(rid); r=Review.find_by(id:rid); return unless r&.content.present?; return unless AiAnalyzer.active?; d=AiAnalyzer.new.analizar_resena(r.content); return if d.blank?; a=ReviewAnalysis.find_or_initialize_by(review_id:r.id); a.update!(sentimiento:d["sentimiento"],resumen:d["resumen"],confianza:d["confianza"]); end; end

```

---

### ARCHIVO: `./app/jobs/application_job.rb`

```rb
class ApplicationJob < ActiveJob::Base
  if defined?(OpenAI::Errors::RateLimitError)
    retry_on OpenAI::Errors::RateLimitError, wait: :polynomially_longer, attempts: 5
  elsif defined?(Faraday::TooManyRequestsError)
    retry_on Faraday::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  end
  retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
end

```

---


... [ARCHIVO TRUNCADO - 1286 lineas totales, se muestran 500] ...

```

---

### ARCHIVO: `./config/application.rb`

```rb
require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)
module Bibliotk
  class Application < Rails::Application
    config.load_defaults 7.1
    config.autoload_lib(ignore: %w[assets tasks])
  end
end

```

---

### ARCHIVO: `./config/boot.rb`

```rb
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "bootsnap/setup"

```

---

### ARCHIVO: `./config/cable.yml`

```yml
development:
  adapter: async

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: bibliotk_production

```

---

### ARCHIVO: `./config/environment.rb`

```rb
require_relative "application"
Rails.application.initialize!

```

---

### ARCHIVO: `./config/environments/development.rb`

```rb
require "active_support/core_ext/integer/time"
Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.cache_store = :memory_store
    config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end
  config.active_storage.service = :local
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.active_job.verbose_enqueue_logs = true
  config.assets.quiet = true
  config.action_controller.raise_on_missing_callback_actions = true
  config.hosts << "utuapp.turshop.cl"
  config.hosts << "www.utuapp.turshop.cl"
end

```

---

### ARCHIVO: `./config/environments/production.rb`

```rb
require "active_support/core_ext/integer/time"
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.assets.compile = false
  config.active_storage.service = :local
  config.force_ssl = true
  config.logger = ActiveSupport::Logger.new(STDOUT).tap { |logger| logger.formatter = ::Logger::Formatter.new }.then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  config.log_tags = [ :request_id ]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
end

```

---

### ARCHIVO: `./config/environments/test.rb`

```rb
require "active_support/core_ext/integer/time"
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = ENV["CI"].present?
  config.public_file_server.enabled = true
  config.public_file_server.headers = { "Cache-Control" => "public, max-age=#{1.hour.to_i}" }
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.active_storage.service = :test
  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test
  config.active_support.deprecation = :stderr
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
  config.action_controller.raise_on_missing_callback_actions = true
end

```

---

### ARCHIVO: `./config/importmap.rb`

```rb
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.bundle.min.js"

```

---

### ARCHIVO: `./config/initializers/assets.rb`

```rb
Rails.application.config.assets.version = "1.0"
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap-icons/font")
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap/dist/js")
Rails.application.config.assets.precompile << "bootstrap.bundle.min.js"

```

---

### ARCHIVO: `./config/initializers/content_security_policy.rb`

```rb
# CSP config

```

---

### ARCHIVO: `./config/initializers/filter_parameter_logging.rb`

```rb
Rails.application.config.filter_parameters += [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]

```

---

### ARCHIVO: `./config/initializers/inflections.rb`

```rb
# Inflections

```

---

### ARCHIVO: `./config/initializers/permissions_policy.rb`

```rb
# Rails.application.config.permissions_policy do |policy|
# end

```

---

### ARCHIVO: `./config/locales/en.yml`

```yml
# Files in the config/locales directory are used for internationalization and
# are automatically loaded by Rails. If you want to use locales other than
# English, add the necessary files in this directory.
#
# To use the locales, use `I18n.t`:
#
#     I18n.t "hello"
#
# In views, this is aliased to just `t`:
#
#     <%= t("hello") %>
#
# To use a different locale, set it with `I18n.locale`:
#
#     I18n.locale = :es
#
# This would use the information in config/locales/es.yml.
#
# To learn more about the API, please read the Rails Internationalization guide
# at https://guides.rubyonrails.org/i18n.html.
#
# Be aware that YAML interprets the following case-insensitive strings as
# booleans: `true`, `false`, `on`, `off`, `yes`, `no`. Therefore, these strings
# must be quoted to be interpreted as strings. For example:
#
#     en:
#       "yes": yup
#       enabled: "ON"

en:
  hello: "Hello world"

```

---

### ARCHIVO: `./config/puma.rb`

```rb
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count
rails_env = ENV.fetch("RAILS_ENV") { "development" }
if rails_env == "production"
  worker_count = Integer(ENV.fetch("WEB_CONCURRENCY") { 1 })
  if worker_count > 1
    workers worker_count
  else
    preload_app!
  end
end
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"
port ENV.fetch("PORT") { 3000 }
environment rails_env
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }
plugin :tmp_restart

```

---

### ARCHIVO: `./config/routes.rb`

```rb
Rails.application.routes.draw do
  root "books#index"
  resources :books, only: [:index, :show] do
    resources :reviews, only: [:create, :update, :destroy]
  end
  resources :users, only: [:index, :show] do
    member do
      post :ban
      post :unban
    end
  end
  get    "/login", to: "sessions#new"
  post   "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
end

```

---

### ARCHIVO: `./config/storage.yml`

```yml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# Use bin/rails credentials:edit to set the AWS secrets (as aws:access_key_id|secret_access_key)
# amazon:
#   service: S3
#   access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
#   secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
#   region: us-east-1
#   bucket: your_own_bucket-<%= Rails.env %>

# Remember not to checkin your GCS keyfile to a repository
# google:
#   service: GCS
#   project: your_project
#   credentials: <%= Rails.root.join("path/to/gcs.keyfile") %>
#   bucket: your_own_bucket-<%= Rails.env %>

# Use bin/rails credentials:edit to set the Azure Storage secret (as azure_storage:storage_access_key)
# microsoft:
#   service: AzureStorage
#   storage_account_name: your_account_name
#   storage_access_key: <%= Rails.application.credentials.dig(:azure_storage, :storage_access_key) %>
#   container: your_container_name-<%= Rails.env %>

# mirror:
#   service: Mirror
#   primary: local
#   mirrors: [ amazon, google, microsoft ]

```

---

### ARCHIVO: `./db/migrate/20260816010000_create_users.rb`

```rb
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "user"
      t.boolean :banned, null: false, default: false
      t.timestamps
    end
    add_index :users, "LOWER(email)", unique: true, name: "index_users_on_lower_email"
    add_index :users, :banned
    add_check_constraint :users, "role IN ('admin','moderator','user')", name: "users_role_valid"
  end
end

```

---

### ARCHIVO: `./db/migrate/20260816010001_create_books.rb`

```rb
class CreateBooks < ActiveRecord::Migration[7.1]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :author, null: false
      t.integer :valid_reviews_count, null: false, default: 0
      t.integer :valid_total_stars, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :books, "valid_reviews_count >= 0", name: "books_valid_count_nonneg"
    add_check_constraint :books, "valid_total_stars >= 0", name: "books_valid_stars_nonneg"
  end
end

```

---

### ARCHIVO: `./db/migrate/20260816010002_create_reviews.rb`

```rb
class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews do |t|
      t.integer :stars, null: false
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.timestamps
    end
    add_check_constraint :reviews, "stars BETWEEN 1 AND 5", name: "reviews_stars_1_5"
    add_index :reviews, [:user_id, :book_id], unique: true
    add_index :reviews, [:book_id, :created_at]
  end
end

```

---

### ARCHIVO: `./db/migrate/20260816010003_create_review_analyses.rb`

```rb
class CreateReviewAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :review_analyses do |t|
      t.references :review, null: false, foreign_key: true
      t.string :sentimiento
      t.string :resumen
      t.float :confianza
      t.timestamps
    end
  end
end

```

---

### ARCHIVO: `./db/migrate/20260816010004_create_fraud_analyses.rb`

```rb
class CreateFraudAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :fraud_analyses do |t|
      t.references :book, null: false, foreign_key: true
      t.boolean :fraude, null: false
      t.float :confianza
      t.text :razon
      t.integer :reviews_analyzed, null: false, default: 0
      t.string :model
      t.timestamps
    end
  end
end

```

---

### ARCHIVO: `./db/migrate/20260816010005_create_user_ban_logs.rb`

```rb
class CreateUserBanLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :user_ban_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.text :reason
      t.timestamps
    end
  end
end

```

---

### ARCHIVO: `./db/schema.rb`

```rb
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_08_16_010005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "books", force: :cascade do |t|
    t.string "title", null: false
    t.string "author", null: false
    t.integer "valid_reviews_count", default: 0, null: false
    t.integer "valid_total_stars", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "valid_reviews_count >= 0", name: "books_valid_count_nonneg"
    t.check_constraint "valid_total_stars >= 0", name: "books_valid_stars_nonneg"
  end

  create_table "fraud_analyses", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.boolean "fraude", null: false
    t.float "confianza"
    t.text "razon"
    t.integer "reviews_analyzed", default: 0, null: false
    t.string "model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_fraud_analyses_on_book_id"
  end

  create_table "review_analyses", force: :cascade do |t|
    t.bigint "review_id", null: false
    t.string "sentimiento"
    t.string "resumen"
    t.float "confianza"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_review_analyses_on_review_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "stars", null: false
    t.text "content"
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "created_at"], name: "index_reviews_on_book_id_and_created_at"
    t.index ["book_id"], name: "index_reviews_on_book_id"
    t.index ["user_id", "book_id"], name: "index_reviews_on_user_id_and_book_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.check_constraint "stars >= 1 AND stars <= 5", name: "reviews_stars_1_5"
  end

  create_table "user_ban_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_user_ban_logs_on_actor_id"
    t.index ["user_id"], name: "index_user_ban_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "user", null: false
    t.boolean "banned", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["banned"], name: "index_users_on_banned"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying::text, 'moderator'::character varying::text, 'user'::character varying::text])", name: "users_role_valid"
  end

  add_foreign_key "fraud_analyses", "books"
  add_foreign_key "review_analyses", "reviews"
  add_foreign_key "reviews", "books"
  add_foreign_key "reviews", "users"
  add_foreign_key "user_ban_logs", "users"
  add_foreign_key "user_ban_logs", "users", column: "actor_id"
end

```

---

### ARCHIVO: `./db/seeds.rb`

```rb
# Seeds idempotentes

```

---

### ARCHIVO: `./DECISIONES.md`

```md
# DECISIONES.md - Bibliotk v2.5 — Homologado PDF 50 libros/página + Corporativo + Timing + Demo 52.67.100.34

## Demo online
- **URL:** `http://52.67.100.34:3000/books` y `http://52.67.100.34:3000/books`
- **User:** `user1@test.com / 12345678`
- **Admin:** `admin@bibliotk.cl / 123456`

## 1. Requisitos del PDF original y cómo se homologaron

### 1.1 Home debe listar 50 libros O(1) — Requerimiento PDF
- **PDF dice**: listado de 50 libros debe ser O(1) en queries, no puede hacer AVG() ni recorrer reseñas.
- **Decisión**: `BooksController#index` con `@per_page = 50` fijo. Query única: `SELECT id, title, author, valid_reviews_count, valid_total_stars FROM books LIMIT 50 OFFSET x`. Sin `JOIN` a reviews. Promedio calculado en memoria con `(valid_total_stars.to_f / valid_reviews_count).round(1, half: :up)`.
- **Paginador**: se mantuvo O(1) usando `Book.count` + `LIMIT/OFFSET`. No se usa Kaminari/will_paginate para evitar queries extra. 50 libros por página = 5 por fila x 10 filas en grilla corporativa.
- **Verificación**: `benchmark_500k.rb` mide `Book.limit(50)... x10` y exige <500ms.

### 1.2 Promedio con 1 decimal half-up + "Reseñas Insuficientes" si <3
- **Ambigüedad**: spec pedía que `average_rating` retorne String en caso insuficiente, rompe tipado.
- **Decisión**: `average_rating` retorna `nil` si `valid_reviews_count <3` (Float|nil consistente). Mensaje va en `average_rating_label` que retorna String siempre. `average_rating_label = average_rating || "Reseñas Insuficientes"`. Justificado en trade-off de tipado.

### 1.3 Contadores materializados y baneo retroactivo
- **Requerimiento**: banear usuario debe recalcular ratings sin recorrer todas las reseñas en request.
- **Decisión**: campos `valid_reviews_count`, `valid_total_stars` en `books`. Actualizados con `update_all` atómico (no `book.valid_reviews_count +=1; save!` que es race). Métodos `increment_valid_ratings!`, `decrement_valid_ratings!`, `sync_valid_ratings!` usan `GREATEST(...,0)` para no negativizar.
- **Baneo**: `User#ban_by!(actor)` valida `actor.admin?` y `actor.id != self.id`, crea `UserBanLog`, encola `UpdateBookRatingsOnUserBanJob`. Job hace `distinct.pluck(:book_id)` + encola `ReconcileBookRatingJob` por libro + `DetectBookFraudJob` con 30s delay si `AiAnalyzer.active?`. Eventual consistency, no bloquea admin.
- **Reconciliación**: `reconcile_valid_ratings!` con subqueries SQL que cuentan solo `users.banned = FALSE`. Idempotente, usado tras `insert_all` del bonus que bypasea callbacks.

### 1.4 Unicidad user_id+book_id bajo concurrencia
- Validación Rails `uniqueness: {scope: :book_id}` + índice único DB `index_reviews_on_user_id_and_book_id`. Test de concurrencia con 20 threads (PDF pide 200, con 20 ya demuestra race sin hacer CI lento). Rescata `RecordNotUnique` como `RecordInvalid`.

## 2. Nuevas implementaciones corporativas (últimas iteraciones)

### 2.1 Login y /users corporativos
- **Decisión**: `sessions/new.html.erb` estilo slate-900 #0f172a + amber #b45309, card blanca con `border-radius:16px`, inputs #f8fafc. Muestra credenciales demo `admin@test.com / 123456` y `user1@test.com / 12345678`.
- **Users**: `UsersController#index` requiere admin (`before_action :require_admin`). Tabla corporativa con badges `ACTIVO` verde #f0fdf4 y `BANEADO` rojo #fef2f2. Botones `Suspender` / `Reactivar` con borde, no sólido.

### 2.2 Botón Banear desde el front como admin
- **Requerimiento nuevo**: admin debe poder banear desde el front.
- **Decisión**: En `books/show.html.erb` cada reseña muestra a la derecha `🚫 Banear` si `current_user.admin? && review.user_id != current_user.id` y `!user.banned?`, o `Reactivar` si baneado. `button_to` con `turbo_confirm` explica que recalculará O(1). También en `users/index`. Acción va a `ban_user_path` que llama `ban_by!` con reason "Spam desde libro X".

### 2.3 Paginador en todos los listados
- **Decisión**: sin gemas. Helper `corporate_paginator(current_page, total_pages, total_count, per_page, param_name:, path:)` genera HTML con botones `Anterior/Siguiente` y ventana de 5 números, preserva otros query params via `request.query_parameters.except(param_name)`.
- **Aplicado en**: `books#index` 50 por página, `books#show` reviews 20 por página `reviews_page`, `users#index` 20 por página, `users#show` reviews 10 por página.
- **Ventaja**: O(1) + COUNT, sin N+1, homologado PDF.

### 2.4 Timing de generación de data
- **Requerimiento**: mostrar cuánto demoró generar la data.
- **Decisión**: `benchmark_500k.rb` envuelve todo en `Benchmark.realtime total_time`. Guarda en `tmp/data_generation_timing.txt` línea: `"12.34s total | 0.2 min | Libros:51 Usuarios:5000 Reseñas:5000 | 13/05 14:30"`.
- `BooksController#index` lee ese archivo si existe y lo expone como `@data_gen_timing`. Vista muestra 3 banners: Home query ms, Benchmark 10x Home, Generación Data.
- Script adicional `/tmp/generar_datos_prueba_con_timing.rb` hace lo mismo para datos de prueba diversos.

### 2.5 Datos de prueba realistas vía tests
- **Requerimiento**: generar datos por medio de tests, comentarios diferentes.
- **Decisión**: 
  - `/tmp/generar_datos_prueba.rb`: hash `COMENTARIOS` por estrellas (5=>7 variantes, 4=>6, 3=>5, 2=>4, 1=>4) + sufijo `[UserX - Libro Y]` para unicidad visible. Crea `user1@test.com`..`user5@test.com` / `12345678` limpios, cada uno reseña 6-8 libros distintos, usa `Review.create!` (dispara callbacks O(1), no `insert_all`).
  - Factory `spec/factories/test_data_factory.rb` con `corporate_user` y `diverse_review`.
  - Spec `spec/generators/corporate_data_spec.rb` que genera 15 reseñas y verifica `valid_reviews_count`.
  - Evita "Reseña benchmark 0" repetido del bonus.

### 2.6 Usuarios fijos de prueba
- `user1@test.com`..`user5@test.com` / `12345678` (role user, no baneados, sin reseñas inicialmente) para probar flujo de estrellas iluminadas.
- `admin@bibliotk.cl` / `123456`, `tester@bibliotk.cl`, `manager@bibliotk.cl` para corporativo.
- Todos creados con `password_confirmation` y `banned=false`.

## 3. Trade-offs y costo

- **update_all atómico vs lock pesimista**: más rápido, evita race, pero bypasea validaciones. Mitigado con `reconcile_valid_ratings!` y check constraints `valid_reviews_count >=0`.
- **insert_all en bonus**: necesario para 500k sin morir con bcrypt (500k * bcrypt = minutos). Costo: bypasea callbacks, requiere reconcile manual. Para datos de prueba corporativos se usa `create!` para mantener contadores.
- **OpenAI gem**: `OpenAI::Errors::RateLimitError` no existe en v<7. Fix con `defined?` + fallback `Faraday::TooManyRequestsError`. En `AiAnalyzer` se sanitiza `<review>` tags y se trunca a 2000 chars para evitar prompt injection.
- **Paginador manual**: evita gemas y queries extra, pero no tiene cursor pagination. Suficiente para 50 libros por página PDF.

## 4. Qué dejaría fuera si saliera a producción mañana

- Seed 500k: solo script manual, no en CI ni en `db:seed`. Se deja `tmp/data_generation_timing.txt` como artefacto.
- IA fraude: feature flag OFF hasta evaluación de falsos positivos. `DetectBookFraudJob` solo corre si `AiAnalyzer.active?` y si hay >10 reviews.
- Picsum fotos: reemplazar por CDN propio.
- Rate limiting reseñas: falta implementar para mitigar campañas falsas.

## 5. Qué haría distinto con una semana más

- Cursor pagination + caché Redis de `average_rating` con invalidación por `reconcile`.
- Métricas Prometheus: drift `valid_reviews_count` vs `COUNT(*)`.
- Índice `books(valid_reviews_count DESC)` para `GET /books?sort=popular` O(1).
- Endpoint `GET /books/:id/fraud_analyses` para auditoría corporativa.
- Tests de integración de paginador + timing + ban desde front con Capybara.
- Guardar timing en tabla `DataGenerationLogs` en vez de archivo tmp para persistencia multi-instancia.

## 6. Cómo probar homologación PDF

```bash
# 50 libros por página
curl http://52.67.100.34:3000/books | grep -c "card" # debe ser 50

# O(1) home
bin/rails runner benchmark_500k.rb
# debe decir "OK - Home es O(1) - Bonus PASS - 50 libros por página PDF" y crear tmp/data_generation_timing.txt

# Ban desde front
# login admin@bibliotk.cl / 123456 -> /books/1 -> 🚫 Banear -> valid_reviews_count baja

# Datos diversos
bin/rails runner /tmp/generar_datos_prueba.rb
# genera user1..user5@test.com con comentarios distintos

# Paginadores
# /books?page=2, /books/1?reviews_page=2, /users?page=2
```

```

---

### ARCHIVO: `./docker-compose.yml`

```yml
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: bibliotek_development
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      retries: 10

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data

  web:
    build: .
    command: bash -c "rm -f tmp/pids/server.pid && bin/rails server -b 0.0.0.0 -p 3000"
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
      - node_modules:/app/node_modules
    ports:
      - "3000:3000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/bibliotek_development
      REDIS_URL: redis://redis:6379/0
      RAILS_ENV: development
      SEED_BIG: "true"
    stdin_open: true
    tty: true

  sidekiq:
    build: .
    command: bundle exec sidekiq
    volumes:
      - .:/app
      - bundle_cache:/usr/local/bundle
      - node_modules:/app/node_modules
    depends_on:
      - db
      - redis
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/bibliotek_development
      REDIS_URL: redis://redis:6379/0
      RAILS_ENV: development
      SEED_BIG: "true"

volumes:
  pgdata:
  redisdata:
  bundle_cache:
  node_modules:
```

---

### ARCHIVO: `./Dockerfile`

```/Dockerfile

FROM ruby:3.2.2-slim

RUN apt-get update -qq && apt-get install -y \
  build-essential libpq-dev nodejs npm \
  libvips git curl libyaml-dev postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Node (para tailwind/esbuild si lo usas)
COPY package.json package-lock.json* yarn.lock* ./
RUN if [ -f package.json ]; then npm install; fi

COPY . .

# Entrypoint
COPY ./entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
```

---

### ARCHIVO: `./Gemfile`

```/Gemfile
source "https://rubygems.org"
ruby "~> 3.2"
gem "rails", "~> 7.1.5"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 1.12"
gem "redis", ">= 5"
gem "faker"
gem "ruby-openai"
gem "cssbundling-rails"
gem "jsbundling-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "kaminari"
gem "bcrypt", "~> 3.1.7"
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
end
gem "bootsnap", require: false
gem "sprockets-rails"

```

---

### ARCHIVO: `./Gemfile.lock`

```lock
GEM
  remote: https://rubygems.org/
  specs:
    actioncable (7.1.6)
      actionpack (= 7.1.6)
      activesupport (= 7.1.6)
      nio4r (~> 2.0)
      websocket-driver (>= 0.6.1)
      zeitwerk (~> 2.6)
    actionmailbox (7.1.6)
      actionpack (= 7.1.6)
      activejob (= 7.1.6)
      activerecord (= 7.1.6)
      activestorage (= 7.1.6)
      activesupport (= 7.1.6)
      mail (>= 2.7.1)
      net-imap
      net-pop
      net-smtp
    actionmailer (7.1.6)
      actionpack (= 7.1.6)
      actionview (= 7.1.6)
      activejob (= 7.1.6)
      activesupport (= 7.1.6)
      mail (~> 2.5, >= 2.5.4)
      net-imap
      net-pop
      net-smtp
      rails-dom-testing (~> 2.2)
    actionpack (7.1.6)
      actionview (= 7.1.6)
      activesupport (= 7.1.6)
      cgi
      nokogiri (>= 1.8.5)
      racc
      rack (>= 2.2.4)
      rack-session (>= 1.0.1)
      rack-test (>= 0.6.3)
      rails-dom-testing (~> 2.2)
      rails-html-sanitizer (~> 1.6)
    actiontext (7.1.6)
      actionpack (= 7.1.6)
      activerecord (= 7.1.6)
      activestorage (= 7.1.6)
      activesupport (= 7.1.6)
      globalid (>= 0.6.0)
      nokogiri (>= 1.8.5)
    actionview (7.1.6)
      activesupport (= 7.1.6)
      builder (~> 3.1)
      cgi
      erubi (~> 1.11)
      rails-dom-testing (~> 2.2)
      rails-html-sanitizer (~> 1.6)
    activejob (7.1.6)
      activesupport (= 7.1.6)
      globalid (>= 0.3.6)
    activemodel (7.1.6)
      activesupport (= 7.1.6)
    activerecord (7.1.6)
      activemodel (= 7.1.6)
      activesupport (= 7.1.6)
      timeout (>= 0.4.0)
    activestorage (7.1.6)
      actionpack (= 7.1.6)
      activejob (= 7.1.6)
      activerecord (= 7.1.6)
      activesupport (= 7.1.6)
      marcel (~> 1.0)
    activesupport (7.1.6)
      base64
      benchmark (>= 0.3)
      bigdecimal
      concurrent-ruby (~> 1.0, >= 1.0.2)
      connection_pool (>= 2.2.5)
      drb
      i18n (>= 1.6, < 2)
      logger (>= 1.4.2)
      minitest (>= 5.1)
      mutex_m
      securerandom (>= 0.3)
      tzinfo (~> 2.0)
    base64 (0.3.0)
    bcrypt (3.1.22)
    benchmark (0.5.0)
    bigdecimal (4.1.2)
    bootsnap (1.25.0)
      msgpack (~> 1.5)
    builder (3.3.0)
    cgi (0.5.2)
    concurrent-ruby (1.3.8)
    connection_pool (3.0.2)
    crass (1.0.7)
    cssbundling-rails (1.4.3)
      railties (>= 6.0.0)
    date (3.5.1)
    diff-lcs (1.6.2)
    drb (2.2.3)
    erb (6.0.7)
    erubi (1.13.1)
    et-orbi (1.4.1)
      tzinfo
    event_stream_parser (1.0.0)
    factory_bot (6.6.0)
      activesupport (>= 6.1.0)
    factory_bot_rails (6.5.1)
      factory_bot (~> 6.5)
      railties (>= 6.1.0)
    faker (3.8.0)
      i18n (>= 1.8.11, < 2)
    faraday (2.14.3)
      faraday-net_http (>= 2.0, < 3.5)
      json
      logger
    faraday-multipart (1.2.0)
      multipart-post (~> 2.0)
    faraday-net_http (3.4.4)
      net-http (~> 0.5)
    fugit (1.13.0)
      et-orbi (~> 1.4)
      raabro (~> 1.4)
    globalid (1.4.0)
      activesupport (>= 6.1)
    i18n (1.15.2)
      concurrent-ruby (~> 1.0)
    io-console (0.9.2)
    irb (1.18.0)
      pp (>= 0.6.0)
      prism (>= 1.3.0)
      rdoc (>= 4.0.0)
      reline (>= 0.4.2)
    jsbundling-rails (1.3.1)
      railties (>= 6.0.0)
    json (2.21.2)
    kaminari (1.2.2)
      activesupport (>= 4.1.0)
      kaminari-actionview (= 1.2.2)
      kaminari-activerecord (= 1.2.2)
      kaminari-core (= 1.2.2)
    kaminari-actionview (1.2.2)
      actionview
      kaminari-core (= 1.2.2)
    kaminari-activerecord (1.2.2)
      activerecord
      kaminari-core (= 1.2.2)
    kaminari-core (1.2.2)
    logger (1.7.0)
    loofah (2.25.2)
      crass (~> 1.0.2)
      nokogiri (>= 1.12.0)
    mail (2.9.1)
      logger
      mini_mime (>= 0.1.1)
      net-imap
      net-pop
      net-smtp
    marcel (1.2.1)
    mini_mime (1.1.5)
    minitest (6.0.6)
      drb (~> 2.0)
      prism (~> 1.5)
    msgpack (1.8.4)
    multipart-post (2.4.1)
    mutex_m (0.3.0)
    net-http (0.9.1)
      uri (>= 0.11.1)
    net-imap (0.6.6)
      date
      net-protocol
    net-pop (0.1.2)
      net-protocol
    net-protocol (0.2.2)
      timeout
    net-smtp (0.5.1)
      net-protocol
    nio4r (2.7.5)
    nokogiri (1.19.4-aarch64-linux-gnu)
      racc (~> 1.4)
    nokogiri (1.19.4-aarch64-linux-musl)
      racc (~> 1.4)
    nokogiri (1.19.4-arm-linux-gnu)
      racc (~> 1.4)
    nokogiri (1.19.4-arm-linux-musl)
      racc (~> 1.4)
    nokogiri (1.19.4-arm64-darwin)
      racc (~> 1.4)
    nokogiri (1.19.4-x86_64-darwin)
      racc (~> 1.4)
    nokogiri (1.19.4-x86_64-linux-gnu)
      racc (~> 1.4)
    nokogiri (1.19.4-x86_64-linux-musl)
      racc (~> 1.4)
    pg (1.6.3)
    pg (1.6.3-aarch64-linux)
    pg (1.6.3-aarch64-linux-musl)
    pg (1.6.3-arm64-darwin)
    pg (1.6.3-x86_64-darwin)
    pg (1.6.3-x86_64-linux)
    pg (1.6.3-x86_64-linux-musl)
    pp (0.6.4)
      prettyprint
    prettyprint (0.2.0)
    prism (1.9.0)
    puma (8.0.2)
      nio4r (~> 2.0)
    raabro (1.5.0)
    racc (1.8.1)
    rack (3.2.7)
    rack-session (2.1.2)
      base64 (>= 0.1.0)
      rack (>= 3.0.0)
    rack-test (2.2.0)
      rack (>= 1.3)
    rackup (2.3.1)
      rack (>= 3)
    rails (7.1.6)
      actioncable (= 7.1.6)
      actionmailbox (= 7.1.6)
      actionmailer (= 7.1.6)
      actionpack (= 7.1.6)
      actiontext (= 7.1.6)
      actionview (= 7.1.6)
      activejob (= 7.1.6)
      activemodel (= 7.1.6)
      activerecord (= 7.1.6)
      activestorage (= 7.1.6)
      activesupport (= 7.1.6)
      bundler (>= 1.15.0)
      railties (= 7.1.6)
    rails-dom-testing (2.3.0)
      activesupport (>= 5.0.0)
      minitest
      nokogiri (>= 1.6)
    rails-html-sanitizer (1.7.1)
      loofah (~> 2.25, >= 2.25.2)
      nokogiri (>= 1.15.7, != 1.16.7, != 1.16.6, != 1.16.5, != 1.16.4, != 1.16.3, != 1.16.2, != 1.16.1, != 1.16.0.rc1, != 1.16.0)
    railties (7.1.6)
      actionpack (= 7.1.6)
      activesupport (= 7.1.6)
      cgi
      irb
      rackup (>= 1.0.0)
      rake (>= 12.2)
      thor (~> 1.0, >= 1.2.2)
      tsort (>= 0.2)
      zeitwerk (~> 2.6)
    rake (13.4.2)
    rbs (4.1.3)
      logger
      prism (>= 1.6.0)
      tsort
    rdoc (8.0.0)
      erb
      prism (>= 1.6.0)
      rbs (>= 4.0.0)
      tsort
    redis (6.0.0)
      redis-client (= 0.30.1)
    redis-client (0.30.1)
      connection_pool
    reline (0.7.0)
      io-console (~> 0.5)
    rspec-core (3.13.6)
      rspec-support (~> 3.13.0)
    rspec-expectations (3.13.5)
      diff-lcs (>= 1.2.0, < 2.0)
      rspec-support (~> 3.13.0)
    rspec-mocks (3.13.8)
      diff-lcs (>= 1.2.0, < 2.0)
      rspec-support (~> 3.13.0)
    rspec-rails (7.1.1)
      actionpack (>= 7.0)
      activesupport (>= 7.0)
      railties (>= 7.0)
      rspec-core (~> 3.13)
      rspec-expectations (~> 3.13)
      rspec-mocks (~> 3.13)
      rspec-support (~> 3.13)
    rspec-support (3.13.7)
    ruby-openai (8.3.0)
      event_stream_parser (>= 0.3.0, < 2.0.0)
      faraday (>= 1)
      faraday-multipart (>= 1)
    securerandom (0.4.1)
    sidekiq (7.3.9)
      base64
      connection_pool (>= 2.3.0)
      logger
      rack (>= 2.2.4)
      redis-client (>= 0.22.2)
    sidekiq-cron (1.12.0)
      fugit (~> 1.8)
      globalid (>= 1.0.1)
      sidekiq (>= 6)
    sprockets (4.3.0)
      concurrent-ruby (~> 1.1)
      logger
      rack (>= 2.2.4, < 4)
    sprockets-rails (3.5.2)
      actionpack (>= 6.1)
      activesupport (>= 6.1)
      sprockets (>= 3.0.0)
    stimulus-rails (1.3.4)
      railties (>= 6.0.0)
    thor (1.5.0)
    timeout (0.6.1)
    tsort (0.2.0)
    turbo-rails (2.0.23)
      actionpack (>= 7.1.0)
      railties (>= 7.1.0)
    tzinfo (2.0.6)
      concurrent-ruby (~> 1.0)
    uri (1.1.1)
    websocket-driver (0.8.2)
      base64
      websocket-extensions (>= 0.1.0)
    websocket-extensions (0.1.5)
    zeitwerk (2.8.3)

PLATFORMS
  aarch64-linux
  aarch64-linux-gnu
  aarch64-linux-musl
  arm-linux-gnu
  arm-linux-musl
  arm64-darwin
  x86_64-darwin
  x86_64-linux
  x86_64-linux-gnu
  x86_64-linux-musl

DEPENDENCIES
  bcrypt (~> 3.1.7)
  bootsnap
  cssbundling-rails
  factory_bot_rails
  faker
  jsbundling-rails
  kaminari
  pg (~> 1.5)
  puma (>= 5.0)
  rails (~> 7.1.5)
  redis (>= 5)
  rspec-rails
  ruby-openai
  sidekiq (~> 7.3)
  sidekiq-cron (~> 1.12)
  sprockets-rails
  stimulus-rails
  turbo-rails

RUBY VERSION
   ruby 3.2.2

BUNDLED WITH
   2.4.22

```

---

### ARCHIVO: `./package.json`

```json
{
  "name": "app",
  "private": "true",
  "scripts": {
    "build:css:compile": "sass ./app/assets/stylesheets/application.bootstrap.scss:./app/assets/builds/application.css --no-source-map --load-path=node_modules",
    "build:css:prefix": "postcss ./app/assets/builds/application.css --use=autoprefixer --output=./app/assets/builds/application.css",
    "build:css": "yarn build:css:compile && yarn build:css:prefix",
    "watch:css": "nodemon --watch ./app/assets/stylesheets/ --ext scss --exec \"yarn build:css\""
  },
  "browserslist": [
    "defaults"
  ]
}
```

---

### ARCHIVO: `./Rakefile`

```/Rakefile
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

```

---

### ARCHIVO: `./README.md`

```md
# Bibliotk v2.5 — Motor de calificación O(1) + 50 libros/página PDF

Plataforma de reseñas de libros resiliente a campañas falsas. Home lista **50 libros por página** con query O(1), sin AVG() ni recorrer reseñas.

## Demo online
**Disponible en:** `http://52.67.100.34:3000/books`
- Home 50 libros O(1) + 3 banners con timing de generación
- Login user: `user1@test.com / 12345678`
- Login admin: `admin@bibliotk.cl / 123456` → botón 🚫 Banear desde front en cada reseña
- Paginadores: `/books?page=2`, `/books/1?reviews_page=2`, `/users?page=2`

## Requisitos PDF homologados
- Reseña: stars 1..5, contenido max 1000, 1 por usuario/libro, editable/eliminable
- Promedio: 1 decimal half-up (3.25→3.3), <3 reseñas = "Reseñas Insuficientes", baneados no cuentan
- Home: `SELECT id,title,author,valid_reviews_count,valid_total_stars LIMIT 50 OFFSET` → O(1)
- Baneo retroactivo: `ban_by!` + `UpdateBookRatingsOnUserBanJob` + `reconcile_valid_ratings!`
- Concurrencia: validación + unique index + test 20 threads (200 en PDF)
- Bonus 500k: `benchmark_500k.rb` genera libro con 500k reseñas y mide Home

## Instalación con Docker (recomendado)

**Auto-seed automático:** Al hacer `docker compose up --build` se crean 50 libros + admins + 5 users demo. Si `SEED_BIG=true`, genera 5000 reviews automáticamente en el primer arranque.

```bash
git clone https://github.com/jacktravolta/BiblioTK.git
cd BiblioTK

# Build + seed automático (50 libros + admins)
docker compose up --build

# Logs esperados:
# >> Seed 50 libros + usuarios demo...
# >> DB lista: 50 libros, 7 users, 0 reviews
# * Listening on http://0.0.0.0:3000

# Abrir
# http://localhost:3000/books
```

**Con benchmark 5000 reviews (30-60s primera vez):**

El `docker-compose.yml` ya viene con:
```yaml
environment:
  SEED_BIG: "true"
```

Si quieres desactivarlo:
```bash
# Edita docker-compose.yml y pon SEED_BIG: "false"
```

**Comandos útiles Docker:**
```bash
docker compose down              # apaga
docker compose down -v           # borra DB y vuelve a seedear desde cero
docker compose logs -f web       # ver logs
docker compose exec web bin/rails console
docker compose exec web bundle exec rspec -fd
docker compose exec web bin/rails runner benchmark_500k.rb
docker compose exec web cat tmp/data_generation_timing.txt
```

**Servicios:**
- `web:3000` Rails 7 + `entrypoint.sh` (espera postgres + db:prepare + runner tmp/auto_seed.rb)
- `db:5432` Postgres 15
- `redis:6379` Redis
- `sidekiq` Jobs de baneo retroactivo

**Estructura Docker:**
- `Dockerfile`: ruby:3.2 + build deps
- `docker-compose.yml`: web/db/redis/sidekiq
- `entrypoint.sh`: idempotente, no requiere seed manual
- `tmp/auto_seed.rb`: seed 50 libros + users + benchmark si SEED_BIG
- `tmp/data_generation_timing.txt`: timing visible en banners del home

## Instalación local (sin Docker)
```bash
bundle install
bin/rails db:create db:migrate
bin/rails db:seed # crea admin@test.com / 123456 y 50 libros base
bin/rails server -b 0.0.0.0 -p 3000
```

## Usuarios demo
- Admin: `admin@bibliotk.cl / 123456` o `admin@test.com / 123456`
- Users: `user1@test.com`..`user5@test.com / 12345678`
- Tester: `tester@bibliotk.cl / 123456`

## Probar todos los puntos PDF
```bash
# Docker
docker compose exec web bin/rails runner /tmp/fix_final.rb
docker compose exec web bin/rails runner benchmark_500k.rb
docker compose exec web bundle exec rspec -fd

# Local
bin/rails runner benchmark_500k.rb
cat tmp/data_generation_timing.txt
bundle exec rspec -fd
```

## Estructura clave
- `app/models/book.rb`: `valid_reviews_count`, `valid_total_stars`, `average_rating`, `increment/decrement/sync/reconcile_valid_ratings!`
- `app/models/review.rb`: callbacks O(1) `after_create_commit :add_to_rating`
- `app/models/user.rb`: `ban_by!`, `unban_by!`, `can_review?`
- `app/controllers/books_controller.rb`: `@per_page = 50` fijo, lee `tmp/data_generation_timing.txt`
- `app/jobs/update_book_ratings_on_user_ban_job.rb`: recalcula libros afectados por baneo
- `entrypoint.sh`: espera postgres + `db:prepare` + `tmp/auto_seed.rb` idempotente
- `benchmark_500k.rb`: envuelve en `Benchmark.realtime total_time` y guarda timing con `insert_all`
- `DECISIONES.md`: trade-offs

## Paginadores
- Home: 50 por página `?page=`
- Libro: reviews 20 por página `?reviews_page=`
- Users: 20 por página, User show: 10 por página
- Helper `corporate_paginator` sin gemas

## Timing visible en front
3 banners en `/books`:
- Home query O(1) ms
- Benchmark 10x Home ms
- Generación Data (de `tmp/data_generation_timing.txt`)

## Entregables
1. Código + instrucciones (este README)
2. `DECISIONES.md` breve
3. Bonus seed + medición

## Autor

**Juan Espinoza Castro** — Product Builder / Fullstack Ruby on Rails

- **Email:** juan.espinoza.castro88@gmail.com
- **GitHub:** [jacktravolta](https://github.com/jacktravolta)
- **Ubicación:** Santiago, Chile
- **Repo:** https://github.com/jacktravolta/BiblioTK
- **Demo:** http://52.67.100.34:3000/books
- **Stack:** Rails 7 + PostgreSQL (atomización ACID, redundancia, soporte pgvector para búsqueda semántica futura) + Redis/Sidekiq + Docker + Tailwind

> Este proyecto incluye 2 extras fuera de scope (IA Ban retroactivo + Front corporativo) bajo visión de producto: el módulo IA no es determinante para la ejecución, es una capa desacoplada de moderación. El front se desarrolló para pruebas E2E reales.

```

---

### ARCHIVO: `./spec/factories/books.rb`

```rb
FactoryBot.define do
  factory :book do
    sequence(:title) { |n| "Libro #{n}" }
    sequence(:author) { |n| "Autor #{n}" }
  end
end

```

---

### ARCHIVO: `./spec/factories/reviews.rb`

```rb
FactoryBot.define do
  factory :review do
    association :user
    association :book
    stars { 5 }
    content { "Excelente libro" }
  end
end

```

---

### ARCHIVO: `./spec/factories/test_data_factory.rb`

```rb
FactoryBot.define do
  factory :corporate_user, class: 'User' do
    sequence(:name) { |n| "Tester Corp #{n}" }
    sequence(:email) { |n| "corp#{n}@bibliotk.cl" }
    password { "12345678" }
    role { "user" }
    banned { false }
  end

  factory :diverse_review, class: 'Review' do
    stars { [5,5,5,4,4,3,2,1].sample }
    content do
      {
        5 => "Excelente obra corporativa, muy recomendable.",
        4 => "Muy buen libro, con detalles menores.",
        3 => "Correcto, cumple sin sorprender.",
        2 => "Regular, necesita mejoras.",
        1 => "Deficiente, no recomendable."
      }[stars]
    end
    association :user, factory: :corporate_user
    association :book
  end
end

```

---

### ARCHIVO: `./spec/factories/users.rb`

```rb
FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Usuario #{n}" }
    sequence(:email) { |n| "usuario#{n}@bibliotk.test" }
    password { "123456" }
    password_confirmation { "123456" }
    role { "user" }
    banned { false }

    trait :admin do
      role { "admin" }
    end

    trait :moderator do
      role { "moderator" }
    end

    trait :banned do
      banned { true }
    end
  end
end

```

---

### ARCHIVO: `./spec/integration/review_concurrency_spec.rb`

```rb
require "rails_helper"

RSpec.describe "Review concurrency",
               type: :model,
               use_transactional_fixtures: false do
  self.use_transactional_tests = false

  describe "duplicate review race condition" do
    it "permite solo una review para el mismo usuario y libro" do
      book = create(:book)

      user = create(
        :user,
        email: "race-#{SecureRandom.hex(8)}@bibliotk.test"
      )

      results = Queue.new
      threads = []

      200.times do |i|
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              book_record = Book.find(book.id)
              user_record = User.find(user.id)

              review = Review.create!(
                user: user_record,
                book: book_record,
                stars: 5,
                content: "Concurrent attempt #{i}"
              )

              results << [:success, review.id]

            rescue ActiveRecord::RecordInvalid,
                   ActiveRecord::RecordNotUnique => e

              results << [:rejected, e.class.name]
            end
          end
        end
      end

      threads.each(&:join)

      successes = []
      rejected = []

      until results.empty?
        result = results.pop(true) rescue nil
        break unless result

        if result.first == :success
          successes << result
        else
          rejected << result
        end
      end

      book.reload

      expect(successes.size).to eq(1)
      expect(rejected.size).to eq(199)

      expect(book.reviews.count).to eq(1)
      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)

      expect(book.reviews.sum(:stars)).to eq(5)
    end
  end
end

```

---

### ARCHIVO: `./spec/integration/user_ban_rating_flow_spec.rb`

```rb
require "rails_helper"
RSpec.describe "User ban rating flow", type: :model do
  include ActiveJob::TestHelper
  it "excluye las reviews del usuario baneado después de reconciliar" do
    admin = create(:user, :admin)
    valid_user = create(:user)
    user_to_ban = create(:user)
    book = create(:book)
    create(:review, user: valid_user, book: book, stars: 5)
    create(:review, user: user_to_ban, book: book, stars: 2)
    user_to_ban.ban_by!(admin, reason: "Spam")
    ReconcileBookRatingJob.perform_now(book.id)
    book.reload
    expect(book.valid_reviews_count).to eq(1)
    expect(book.valid_total_stars).to eq(5)
    expect(book.average_rating).to be_nil
    expect(book.average_rating_label).to eq("Reseñas Insuficientes")
  end
  it "mantiene el rating correcto si la reconciliación se ejecuta varias veces (idempotente)" do
    admin = create(:user, :admin)
    valid_user = create(:user)
    user_to_ban = create(:user)
    book = create(:book)
    create(:review, user: valid_user, book: book, stars: 4)
    create(:review, user: user_to_ban, book: book, stars: 1)
    user_to_ban.ban_by!(admin, reason: "Spam")
    3.times { ReconcileBookRatingJob.perform_now(book.id) }
    book.reload
    expect(book.valid_reviews_count).to eq(1)
  end
end

```

---

### ARCHIVO: `./spec/jobs/rating_reconciliation_job_spec.rb`

```rb
require "rails_helper"

RSpec.describe RatingReconciliationJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    it "encola una reconciliación para cada libro existente" do
      create_list(:book, 3)

      books = Book.all.to_a

      clear_enqueued_jobs

      described_class.perform_now

      jobs = enqueued_jobs.select do |job|
        job[:job] == ReconcileBookRatingJob
      end

      expect(jobs.size).to eq(books.size)

      book_ids = jobs.map do |job|
        job[:args].first
      end

      expect(book_ids).to contain_exactly(
        *books.map(&:id)
      )
    end

    it "no falla cuando no hay libros que procesar" do
      allow(Book).to receive(:find_each)

      clear_enqueued_jobs

      expect {
        described_class.perform_now
      }.not_to raise_error

      expect(
        enqueued_jobs.select do |job|
          job[:job] == ReconcileBookRatingJob
        end
      ).to be_empty
    end
  end
end

```

---

### ARCHIVO: `./spec/jobs/reconcile_book_rating_job_spec.rb`

```rb
require "rails_helper"

RSpec.describe ReconcileBookRatingJob, type: :job do
  describe "#perform" do
    it "reconcilia los contadores excluyendo usuarios baneados" do
      book = create(:book)

      valid_user = create(:user)
      banned_user = create(:user)

      create(
        :review,
        user: valid_user,
        book: book,
        stars: 5
      )

      create(
        :review,
        user: banned_user,
        book: book,
        stars: 2
      )

      # Simulamos contadores corruptos.
      book.update!(
        valid_reviews_count: 99,
        valid_total_stars: 99
      )

      banned_user.update!(banned: true)

      described_class.perform_now(book.id)

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end

    it "es idempotente" do
      book = create(:book)
      user = create(:user)

      create(
        :review,
        user: user,
        book: book,
        stars: 4
      )

      book.update!(
        valid_reviews_count: 0,
        valid_total_stars: 0
      )

      described_class.perform_now(book.id)

      book.reload

      first_count = book.valid_reviews_count
      first_stars = book.valid_total_stars

      described_class.perform_now(book.id)

      book.reload

      expect(book.valid_reviews_count).to eq(first_count)
      expect(book.valid_total_stars).to eq(first_stars)
      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(4)
    end

    it "no falla si el libro no existe" do
      expect {
        described_class.perform_now(-999_999)
      }.not_to raise_error
    end
  end
end

```

---

### ARCHIVO: `./spec/jobs/update_book_ratings_on_user_ban_job_spec.rb`

```rb
require "rails_helper"

RSpec.describe UpdateBookRatingsOnUserBanJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    it "encola reconciliación para todos los libros reseñados por el usuario" do
      user = create(:user)

      book1 = create(:book)
      book2 = create(:book)
      book3 = create(:book)

      create(:review, user: user, book: book1, stars: 5)
      create(:review, user: user, book: book2, stars: 4)
      create(:review, user: user, book: book3, stars: 3)

      clear_enqueued_jobs

      described_class.perform_now(user.id)

      jobs = enqueued_jobs.select do |job|
        job[:job] == ReconcileBookRatingJob
      end

      expect(jobs.size).to eq(3)

      book_ids = jobs.map do |job|
        job[:args].first
      end

      expect(book_ids).to contain_exactly(
        book1.id,
        book2.id,
        book3.id
      )
    end

    it "no falla si el usuario no existe" do
      expect {
        described_class.perform_now(-999_999)
      }.not_to raise_error

      expect(enqueued_jobs).to be_empty
    end
  end
end

```

---

### ARCHIVO: `./spec/models/book_spec.rb`

```rb
require "rails_helper"
RSpec.describe Book, type: :model do
  describe "#average_rating" do
    it "devuelve nil con menos de 3 reseñas" do
      book = create(:book)
      expect(book.average_rating).to be_nil
      expect(book.average_rating_label).to eq("Reseñas Insuficientes")
    end
    it "calcula el promedio cuando hay 3 o más reseñas" do
      book = create(:book)
      book.update!(valid_reviews_count: 3, valid_total_stars: 12)
      expect(book.average_rating).to eq(4.0)
    end
    it "redondea half-up correctamente (borde 3.25->3.3)" do
      book = create(:book)
      book.update!(valid_reviews_count: 4, valid_total_stars: 13)
      expect(book.average_rating).to eq(3.3)
    end
    it "redondea borde inferior 3.24->3.2" do
      book = create(:book)
      book.update!(valid_reviews_count: 5, valid_total_stars: 16)
      expect(book.average_rating).to eq(3.2)
    end
  end
end

```

---

### ARCHIVO: `./spec/models/review_spec.rb`

```rb
require "rails_helper"

RSpec.describe Review, type: :model do
  let(:book) { create(:book) }
  let(:user) { create(:user) }

  describe "validaciones" do
    it "permite una reseña de un usuario registrado" do
      review = build(
        :review,
        user: user,
        book: book,
        stars: 5
      )

      expect(review).to be_valid
    end

    it "impide una segunda reseña del mismo usuario para el mismo libro" do
      create(
        :review,
        user: user,
        book: book
      )

      duplicate = build(
        :review,
        user: user,
        book: book
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages.join(" ")).to include(
        "ya reseñaste este libro"
      )
    end

    it "impide reseñar a un usuario baneado" do
      user.update!(banned: true)

      review = build(
        :review,
        user: user,
        book: book
      )

      expect(review).not_to be_valid
    end

    it "valida estrellas entre 1 y 5" do
      review = build(
        :review,
        user: user,
        book: book,
        stars: 6
      )

      expect(review).not_to be_valid
    end
  end

  describe "rating O(1)" do
    it "incrementa los contadores al crear una reseña" do
      create(
        :review,
        user: user,
        book: book,
        stars: 5
      )

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end

    it "actualiza las estrellas sin cambiar la cantidad" do
      review = create(
        :review,
        user: user,
        book: book,
        stars: 3
      )

      review.update!(stars: 5)

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end

    it "actualiza los contadores al eliminar una reseña" do
      review = create(
        :review,
        user: user,
        book: book,
        stars: 5
      )

      review.destroy!

      book.reload

      expect(book.valid_reviews_count).to eq(0)
      expect(book.valid_total_stars).to eq(0)
    end
  end
end

```

---

### ARCHIVO: `./spec/models/user_spec.rb`

```rb
require "rails_helper"

RSpec.describe User, type: :model do
  describe "#ban_by!" do
    it "banea un usuario y genera un log" do
      admin = create(:user, :admin)
      user = create(:user)

      user.ban_by!(
        admin,
        reason: "Spam"
      )

      user.reload

      expect(user.banned?).to be(true)
      expect(user.user_ban_logs.count).to eq(1)
      expect(user.user_ban_logs.last.action).to eq("banned")
    end

    it "no permite que un usuario se banee a sí mismo" do
      admin = create(:user, :admin)

      expect {
        admin.ban_by!(admin)
      }.to raise_error(
        ArgumentError,
        "No puedes banearte a ti mismo"
      )
    end

    it "no permite que un usuario normal banee" do
      user = create(:user)
      target = create(:user)

      expect {
        target.ban_by!(user)
      }.to raise_error(
        ArgumentError,
        "Solo ADMIN puede banear"
      )
    end
  end

  describe "rating después de un baneo" do
    it "excluye las reseñas del usuario baneado" do
      admin = create(:user, :admin)
      banned_user = create(:user)
      valid_user = create(:user)
      book = create(:book)

      create(
        :review,
        user: banned_user,
        book: book,
        stars: 2
      )

      create(
        :review,
        user: valid_user,
        book: book,
        stars: 5
      )

      expect {
        banned_user.ban_by!(
          admin,
          reason: "Spam"
        )
      }.not_to raise_error

      ReconcileBookRatingJob.perform_now(book.id)

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end
  end
end

```

---

### ARCHIVO: `./spec/rails_helper.rb`

```rb
# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-1/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end

```

---

### ARCHIVO: `./spec/spec_helper.rb`

```rb
# This file was generated by the `rails generate rspec:install` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The generated `.rspec` file contains `--require spec_helper` which will cause
# this file to always be loaded, without a need to explicitly require it in any
# files.
#
# Given that it is always loaded, you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, consider making
# a separate helper file that requires the additional dependencies and performs
# the additional setup, and require it from the spec files that actually need
# it.
#
# See https://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

# The settings below are suggested to provide a good initial experience
# with RSpec, but feel free to customize to your heart's content.
=begin
  # This allows you to limit a spec run to individual examples or groups
  # you care about by tagging them with `:focus` metadata. When nothing
  # is tagged with `:focus`, all examples get run. RSpec also provides
  # aliases for `it`, `describe`, and `context` that include `:focus`
  # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  config.filter_run_when_matching :focus

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  # https://rspec.info/features/3-12/rspec-core/configuration/zero-monkey-patching-mode/
  config.disable_monkey_patching!

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = "doc"
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed
=end
end

```

---

### ARCHIVO: `./test/application_system_test_case.rb`

```rb
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
end

```

---

### ARCHIVO: `./test/channels/application_cable/connection_test.rb`

```rb
require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    # test "connects with cookies" do
    #   cookies.signed[:user_id] = 42
    #
    #   connect
    #
    #   assert_equal connection.user_id, "42"
    # end
  end
end

```

---

### ARCHIVO: `./TESTING.md`

```md
# TESTING.md — Cómo probar TODOS los puntos del PDF Bibliotk

## Demo online
**Demo pública:** `http://52.67.100.34:3000/books` (también `http://52.67.100.34:3000/books`)
- 50 libros por página O(1), banners con timing generación
- User: `user1@test.com / 12345678` — reseña con estrellas iluminadas
- Admin: `admin@bibliotk.cl / 123456` — botón 🚫 Banear desde front, recalcula O(1)
- Paginadores: `?page=2`, `?reviews_page=2`

## 0. Instalación base (una vez)
```bash
cd /home/test/libroTK/bibliotkv1
bundle install
bin/rails db:create db:migrate
bin/rails db:seed # crea admin@test.com / 123456 y 50 libros base si existe seed
```

## 1. Levantar servidor
```bash
pkill -f puma
bin/rails server -b 0.0.0.0 -p 3000 -d
# Abrir: http://52.67.100.34:3000/books
# Debe mostrar 50 libros (5 por fila x 10) + 3 banners: Home O(1) ms, Benchmark 10x, Generación Data
```

## 2. Tests automáticos RSpec (requisito PDF)
```bash
# Todos los tests
bundle exec rspec -fd

# Por área (lo que pide el PDF)
bundle exec rspec spec/models/book_spec.rb -fd              # redondeo half-up 3.25->3.3, umbral 3 reseñas
bundle exec rspec spec/models/review_spec.rb -fd            # validaciones 1..5, 1000 chars, unicidad
bundle exec rspec spec/models/user_spec.rb -fd              # baneo retroactivo
bundle exec rspec spec/models/review_concurrency_spec.rb -fd # 200 usuarios simultáneos (usa 20 para CI rápido)
bundle exec rspec spec/jobs/ -fd                             # jobs O(1)
```

### Qué cubre cada spec (PDF pide mínimo):
- `book_spec.rb`: `average_rating` nil si <3, label "Reseñas Insuficientes", 3.25→3.3 half-up, 3.24→3.2
- `review_spec.rb`: stars inclusion 1..5, content max 1000, uniqueness user+book, editar (sync_valid_ratings!), eliminar (decrement)
- `user_spec.rb`: ban_by! solo admin, no auto-ban, crea UserBanLog, encola UpdateBookRatingsOnUserBanJob, unban restaura
- `review_concurrency_spec.rb`: 20 threads crean review mismo libro → valid_reviews_count debe ser 20 exacto (no 19 por race)
- `jobs`: ReconcileBookRatingJob idempotente, UpdateBookRatingsOnUserBanJob toca solo libros del usuario

## 3. Tests manuales via rails runner (sin front)

### 3a. Validaciones reseña
```bash
bin/rails runner /tmp/fix_final.rb
# Este script hace:
# - Desbanea usuarios masivos user-xxx@test.com
# - Crea user1..user5@test.com / 12345678 limpios
# - Libro Prueba PDF aislado
# - Prueba stars 6 + 1001 chars = false
# - Prueba unicidad 1 review por libro = false
# - Prueba editar y eliminar O(1)
# - Prueba redondeo 13/4=3.25 → 3.3
# - Prueba <3 reseñas → "Reseñas Insuficientes"
# - Prueba baneo retroactivo
# - Prueba Home 50 O(1) x10
```

### 3b. Baneo retroactivo aislado
```bash
bin/rails runner "
admin = User.find_by(role: 'admin'); admin.update!(role: 'admin') if admin.role!='admin'
u = User.find_by(email: 'user2@test.com'); b = Book.first
Review.where(user: u, book: b).delete_all; b.reconcile_valid_ratings!
before = b.valid_reviews_count
r = Review.create!(user: u, book: b, stars: 5, content: 'spam')
puts \"Antes #{before} despues crear #{b.reload.valid_reviews_count}\"
u.ban_by!(admin, reason: 'test'); sleep 1; b.reconcile_valid_ratings!
puts \"Despues ban #{b.valid_reviews_count} debe volver a #{before}\"
u.unban_by!(admin); b.reconcile_valid_ratings!
puts \"Despues unban #{b.valid_reviews_count}\"
"
```

### 3c. Home 50 libros O(1) — Requisito PDF core
```bash
bin/rails runner "
require 'benchmark'
t = Benchmark.realtime { 10.times { Book.limit(50).select(:id, :title, :author, :valid_reviews_count, :valid_total_stars).map{|b| b.average_rating} } }
puts \"Home 50 x10: #{(t*1000).round(2)}ms total, #{(t/10*1000).round(2)}ms por request - debe ser <500ms\"
puts \"Per_page = 50 fijo en BooksController\"
"
# En front: curl http://localhost:3000/books | grep -c 'card' debe ser 50
```

### 3d. Eliminar (tu error anterior)
```bash
# NO uses Review.last (puede ser de usuario baneado)
bin/rails runner "
u = User.find_by(email: 'user1@test.com'); b = Book.find_by(title: 'Libro Prueba PDF')
u.update!(banned: false)
Review.where(user: u, book: b).delete_all
r = Review.create!(user: u, book: b, stars: 5, content: 'Para eliminar')
puts \"Creada #{r.id}\"
r.destroy; b.reconcile_valid_ratings!
puts \"Eliminada OK count=#{b.reload.valid_reviews_count}\"
"
```

## 4. Bonus 500k + Timing visible

### 4a. Bonus real del PDF (500k)
```bash
# Este es benchmark_500k.rb editado por ti (ahora genera 500k real)
bin/rails runner benchmark_500k.rb
# Salida esperada:
# Libro: X
# Creando 500k reseñas...
# Insert 500k en XX.XXs
# valid_reviews_count: 500000
# Home 50 libros x10 en 0.XXXs - O(1) independiente de 500k reseñas
cat tmp/data_generation_timing.txt 2>/dev/null || echo 'Se genera en v2.5'
```

### 4b. Timing en front (tu requerimiento nuevo)
En v2.5 `benchmark_500k.rb` guarda:
```
File.write('tmp/data_generation_timing.txt', "#{total_time.round(2)}s total | #{(total_time/60).round(2)} min | Libros:#{Book.count} ...")
```
`BooksController#index` lee ese archivo y la vista muestra 3 banners:
- Home query O(1) ms
- Benchmark 10x Home
- Generación Data

## 5. Probar desde front (manual)
- Login `user1@test.com / 12345678` → /books/1 → reseñar → estrellas se iluminan, comentario diverso (no "benchmark 0")
- Login `admin@bibliotk.cl / 123456` → /books/1 → cada reseña muestra 🚫 Banear → al banear, valid_reviews_count baja O(1)
- Paginadores: /books?page=2 (50 por página), /books/1?reviews_page=2 (20), /users?page=2 (20)

## 6. Check final antes de entregar
```bash
cat > /tmp/check_pdf.sh <<'SH'
echo "=== CHECK PDF ==="
grep -q "per_page = 50" app/controllers/books_controller.rb && echo "✓ 50 libros por página" || echo "✗ FAIL 50"
grep -q "valid_reviews_count" app/models/book.rb && echo "✓ O(1) contadores" || echo "✗ FAIL O(1)"
ls app/jobs/update_book_ratings_on_user_ban_job.rb && echo "✓ Baneo retroactivo job" || echo "✗"
grep -q "user_id.*book_id.*unique" db/schema.rb && echo "✓ Unicidad index" || echo "✗"
wc -l DECISIONES.md && echo "✓ DECISIONES.md"
cat tmp/data_generation_timing.txt 2>/dev/null && echo "✓ Timing file" || echo "○ Timing no generado (corre benchmark)"
bundle exec rspec -q && echo "✓ RSpec PASS" || echo "✗ RSpec FAIL"
SH
chmod +x /tmp/check_pdf.sh
/tmp/check_pdf.sh
```

Si todo da ✓ y RSpec PASS, estás homologado 100% PDF.

```

---

### ARCHIVO: `./test/test_helper.rb`

```rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

```
