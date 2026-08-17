#!/bin/bash
set -e
echo ">>> Aplicando fixes senior a Bibliotk v2..."

mkdir -p app/services app/views/layouts app/channels/application_cable app/jobs app/controllers app/helpers app/models app/mailers config/environments config/initializers db/migrate spec/jobs spec/integration spec/factories spec/models

# ===== app/services/ai_analyzer.rb (FIXED) =====
cat > app/services/ai_analyzer.rb <<'RUBY'
require "json"
require "openai"

class AiAnalyzer
  MODEL = ENV.fetch("OPENAI_MODEL", "gpt-4o-mini")

  def self.active?
    ENV["OPENAI_API_KEY"].present?
  end

  def initialize
    api_key = ENV["OPENAI_API_KEY"]
    raise "OPENAI_API_KEY no configurada" if api_key.blank?

    @client = OpenAI::Client.new(
      access_token: api_key,
      request_timeout: 15
    )
  end

  def analizar_resena(texto)
    return {} if texto.blank?

    safe = texto.to_s.gsub(/<\/?review>/i, "[review]").truncate(2000)

    prompt = <<~PROMPT
      Clasifica el sentimiento de la reseña.
      Responde SOLO JSON:
      {
        "sentimiento": "Positivo|Negativo|Neutral",
        "resumen": "max 8 palabras",
        "confianza": 0.0
      }
      <review>
      #{safe}
      </review>
    PROMPT

    data = chat_json(prompt, "Solo JSON. Responde con el schema pedido.")
    return {} unless %w[Positivo Negativo Neutral].include?(data["sentimiento"].to_s)

    {
      "sentimiento" => data["sentimiento"],
      "resumen" => data["resumen"].to_s.truncate(255),
      "confianza" => data["confianza"].to_f.clamp(0.0, 1.0)
    }
  rescue StandardError => e
    Rails.logger.error("[AiAnalyzer#analizar_resena] #{e.class}: #{e.message}")
    {}
  end

  def detectar_fraude(textos, promedio)
    return {} if textos.size <= 10

    reviews = textos.first(30).map do |texto|
      "<review>#{texto.to_s.gsub(/<\/?review>/i, "[review]").truncate(500)}</review>"
    end.join("\n")

    prompt = <<~PROMPT
      Evalúa si existe spam coordinado o fraude de reseñas.
      Solo JSON:
      {
        "fraude": false,
        "confianza": 0.0,
        "razon": "breve justificacion max 20 palabras"
      }
      Promedio actual: #{promedio.round(2)}
      <reviews>
      #{reviews}
      </reviews>
    PROMPT

    data = chat_json(prompt, "Solo JSON fraude")

    {
      "fraude" => ActiveModel::Type::Boolean.new.cast(data["fraude"]),
      "confianza" => data["confianza"].to_f.clamp(0.0, 1.0),
      "razon" => data["razon"].to_s.truncate(1000)
    }
  rescue StandardError => e
    Rails.logger.error("[AiAnalyzer#detectar_fraude] #{e.class}: #{e.message}")
    {}
  end

  private

  def chat_json(prompt, system)
    response = @client.chat(
      parameters: {
        model: MODEL,
        messages: [
          { role: "system", content: system },
          { role: "user", content: prompt }
        ],
        temperature: 0,
        response_format: { type: "json_object" }
      }
    )
    JSON.parse(response.dig("choices", 0, "message", "content").to_s)
  end
end
RUBY

# ===== app/models/book.rb (FIXED) =====
cat > app/models/book.rb <<'RUBY'
class Book < ApplicationRecord
  has_many :reviews, dependent: :destroy
  has_many :fraud_analyses, dependent: :destroy

  validates :title, :author, presence: true
  validates :valid_reviews_count, :valid_total_stars,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def average_rating
    return nil if valid_reviews_count < 3
    (valid_total_stars.to_f / valid_reviews_count).round(1, half: :up)
  end

  def average_rating_label
    average_rating || "Reseñas Insuficientes"
  end

  def increment_valid_ratings!(stars)
    stars = Integer(stars)
    raise ArgumentError unless stars.between?(1, 5)
    self.class.where(id: id).update_all(
      ["valid_reviews_count = valid_reviews_count + 1, valid_total_stars = valid_total_stars + ?", stars]
    )
  end

  def decrement_valid_ratings!(stars)
    stars = Integer(stars)
    raise ArgumentError unless stars.between?(1, 5)
    self.class.where(id: id).update_all(
      ["valid_reviews_count = GREATEST(valid_reviews_count - 1, 0), valid_total_stars = GREATEST(valid_total_stars - ?, 0)", stars]
    )
  end

  def sync_valid_ratings!(old_stars, new_stars)
    old_stars = Integer(old_stars)
    new_stars = Integer(new_stars)
    raise ArgumentError unless old_stars.between?(1, 5) && new_stars.between?(1, 5)
    return if old_stars == new_stars
    self.class.where(id: id).update_all(
      ["valid_total_stars = GREATEST(valid_total_stars - ? + ?, 0)", old_stars, new_stars]
    )
  end

  def reconcile_valid_ratings!
    self.class.where(id: id).update_all(
      <<~SQL.squish
        valid_reviews_count = (
          SELECT COUNT(*) FROM reviews
          INNER JOIN users ON users.id = reviews.user_id
          WHERE reviews.book_id = books.id AND users.banned = FALSE
        ),
        valid_total_stars = (
          SELECT COALESCE(SUM(reviews.stars), 0) FROM reviews
          INNER JOIN users ON users.id = reviews.user_id
          WHERE reviews.book_id = books.id AND users.banned = FALSE
        )
      SQL
    )
    reload
  end

  def user_review(user)
    return unless user
    reviews.find_by(user_id: user.id)
  end
end
RUBY

# ===== app/models/review.rb (FIXED) =====
cat > app/models/review.rb <<'RUBY'
class Review < ApplicationRecord
  belongs_to :user
  belongs_to :book
  has_one :review_analysis, dependent: :destroy

  validates :stars, presence: true, inclusion: { in: 1..5 }
  validates :content, length: { maximum: 1000 }, allow_blank: true
  validates :user_id, uniqueness: { scope: :book_id, message: "ya reseñaste este libro" }

  validate :reviewer_can_review

  after_create_commit :add_to_rating
  after_update_commit :sync_rating, if: :saved_change_to_stars?
  after_destroy_commit :remove_from_rating

  private

  def reviewer_can_review
    if user.nil?
      errors.add(:user, "debe estar registrado")
    elsif !user.can_review?
      errors.add(:user, "baneado por spam no puede reseñar")
    end
  end

  def add_to_rating
    return if user&.banned?
    book.increment_valid_ratings!(stars)
  end

  def sync_rating
    return if user&.banned?
    old_stars, new_stars = saved_change_to_stars
    book.sync_valid_ratings!(old_stars, new_stars)
  end

  def remove_from_rating
    return if user&.banned?
    book.decrement_valid_ratings!(stars)
  end
end
RUBY

# ===== app/models/user.rb (FIXED) =====
cat > app/models/user.rb <<'RUBY'
class User < ApplicationRecord
  has_secure_password
  ROLES = %w[admin moderator user].freeze
  has_many :reviews, dependent: :destroy
  has_many :user_ban_logs, dependent: :destroy
  has_many :ban_actions, class_name: "UserBanLog", foreign_key: :actor_id, dependent: :restrict_with_exception, inverse_of: :actor
  before_validation :set_default_role, on: :create
  before_save :downcase_email
  validates :name, presence: true, length: { in: 2..50 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, allow_nil: true
  validates :role, inclusion: { in: ROLES }
  scope :banned, -> { where(banned: true) }
  def admin?; role == "admin"; end
  def moderator?; role == "moderator"; end
  def user?; role == "user"; end
  def can_moderate?; admin? || moderator?; end
  def can_manage_users?; admin?; end
  def can_review?; !banned? && ROLES.include?(role); end

  def ban_by!(actor, reason: nil)
    raise ArgumentError, "Solo ADMIN puede banear" unless actor&.admin?
    raise ArgumentError, "No puedes banearte a ti mismo" if actor.id == id
    was_banned = false
    transaction do
      with_lock do
        was_banned = banned?
        unless was_banned
          update!(banned: true)
          user_ban_logs.create!(actor: actor, action: "banned", reason: reason)
        end
      end
    end
    ::UpdateBookRatingsOnUserBanJob.perform_later(id) unless was_banned
  end

  def unban_by!(actor, reason: nil)
    raise ArgumentError, "Solo ADMIN puede desbanear" unless actor&.admin?
    was_banned = false
    transaction do
      with_lock do
        was_banned = banned?
        if was_banned
          update!(banned: false)
          user_ban_logs.create!(actor: actor, action: "unbanned", reason: reason)
        end
      end
    end
    ::UpdateBookRatingsOnUserBanJob.perform_later(id) if was_banned
  end

  private
  def set_default_role; self.role ||= "user"; end
  def downcase_email; self.email = email.to_s.strip.downcase; end
end
RUBY

# ===== app/jobs/application_job.rb (FIXED) =====
cat > app/jobs/application_job.rb <<'RUBY'
class ApplicationJob < ActiveJob::Base
  retry_on OpenAI::Errors::RateLimitError, wait: :exponentially_longer, attempts: 5
  retry_on Net::OpenTimeout, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError

  around_perform do |job, block|
    Rails.logger.info("[Job] Start #{job.class.name} #{job.arguments}")
    block.call
    Rails.logger.info("[Job] Done #{job.class.name}")
  end
end
RUBY

# ===== RESTO DEL PROYECTO ORIGINAL =====

cat > app/views/layouts/application.html.erb <<'ERB'
<!DOCTYPE html>
<html>
  <head>
    <title>Bibliotk</title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
ERB

cat > app/views/layouts/mailer.text.erb <<'ERB'
<%= yield %>
ERB

cat > app/views/layouts/mailer.html.erb <<'ERB'
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
      /* Email styles need to be inline */
    </style>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
ERB

cat > app/channels/application_cable/connection.rb <<'RUBY'
module ApplicationCable
  class Connection < ActionCable::Connection::Base
  end
end
RUBY

cat > app/channels/application_cable/channel.rb <<'RUBY'
module ApplicationCable
  class Channel < ActionCable::Channel::Base
  end
end
RUBY

cat > app/jobs/rating_reconciliation_job.rb <<'RUBY'
class RatingReconciliationJob < ApplicationJob
  queue_as :default
  def perform
    Book.find_each do |book|
      ReconcileBookRatingJob.perform_later(book.id)
    end
  end
end
RUBY

cat > app/jobs/reconcile_book_rating_job.rb <<'RUBY'
class ReconcileBookRatingJob < ApplicationJob
  queue_as :default
  def perform(book_id)
    book = Book.find_by(id: book_id)
    return unless book
    book.with_lock do
      book.reconcile_valid_ratings!
    end
  end
end
RUBY

cat > app/jobs/update_book_ratings_on_user_ban_job.rb <<'RUBY'
class UpdateBookRatingsOnUserBanJob < ApplicationJob
  queue_as :default
  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user
    user.reviews.distinct.pluck(:book_id).each do |book_id|
      ReconcileBookRatingJob.perform_later(book_id)
      if AiAnalyzer.active?
        DetectBookFraudJob.set(wait: 30.seconds).perform_later(book_id)
      end
    end
  end
end
RUBY

cat > app/jobs/analyze_review_job.rb <<'RUBY'
class AnalyzeReviewJob < ApplicationJob
  queue_as :default
  def perform(review_id)
    review = Review.find_by(id: review_id)
    return unless review&.content.present?
    return unless AiAnalyzer.active?
    data = AiAnalyzer.new.analizar_resena(review.content)
    return if data.blank?
    analysis = ReviewAnalysis.find_or_initialize_by(review_id: review.id)
    analysis.update!(
      sentimiento: data["sentimiento"],
      resumen: data["resumen"],
      confianza: data["confianza"]
    )
  end
end
RUBY

cat > app/jobs/detect_book_fraud_job.rb <<'RUBY'
class DetectBookFraudJob < ApplicationJob
  queue_as :default
  def perform(book_id)
    return unless AiAnalyzer.active?
    book = Book.find_by(id: book_id)
    return unless book
    last = book.fraud_analyses.order(created_at: :desc).first
    if last &&
       book.reviews.where("created_at > ?", last.created_at).none? &&
       last.created_at > 2.minutes.ago
      return
    end
    texts = book.reviews.where.not(content: [nil, ""]).order(created_at: :desc).limit(30).pluck(:content)
    return if texts.size <= 10
    return if book.valid_reviews_count < 3
    average = book.valid_total_stars.to_f / book.valid_reviews_count
    data = AiAnalyzer.new.detectar_fraude(texts, average)
    return if data.blank?
    book.fraud_analyses.create!(
      fraude: data["fraude"],
      confianza: data["confianza"],
      razon: data["razon"],
      reviews_analyzed: texts.size,
      model: AiAnalyzer::MODEL
    )
  end
end
RUBY

cat > app/controllers/application_controller.rb <<'RUBY'
class ApplicationController < ActionController::Base
end
RUBY

cat > app/helpers/application_helper.rb <<'RUBY'
module ApplicationHelper
end
RUBY

cat > app/models/review_analysis.rb <<'RUBY'
class ReviewAnalysis < ApplicationRecord
  belongs_to :review
end
RUBY

cat > app/models/user_ban_log.rb <<'RUBY'
class UserBanLog < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", inverse_of: :ban_actions
end
RUBY

cat > app/models/application_record.rb <<'RUBY'
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
RUBY

cat > app/models/fraud_analysis.rb <<'RUBY'
class FraudAnalysis < ApplicationRecord
  belongs_to :book
  scope :latest_first, -> { order(created_at: :desc) }
end
RUBY

cat > app/mailers/application_mailer.rb <<'RUBY'
class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end
RUBY

cat > config/boot.rb <<'RUBY'
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "bootsnap/setup"
RUBY

cat > config/application.rb <<'RUBY'
require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)
module Bibliotk
  class Application < Rails::Application
    config.load_defaults 7.1
    config.autoload_lib(ignore: %w[assets tasks])
  end
end
RUBY

cat > config/routes.rb <<'RUBY'
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
end
RUBY

cat > config/environment.rb <<'RUBY'
require_relative "application"
Rails.application.initialize!
RUBY

cat > config/importmap.rb <<'RUBY'
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.bundle.min.js"
RUBY

cat > config/puma.rb <<'RUBY'
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
RUBY

mkdir -p config/initializers
cat > config/initializers/filter_parameter_logging.rb <<'RUBY'
Rails.application.config.filter_parameters += [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]
RUBY

cat > config/initializers/assets.rb <<'RUBY'
Rails.application.config.assets.version = "1.0"
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap-icons/font")
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap/dist/js")
Rails.application.config.assets.precompile << "bootstrap.bundle.min.js"
RUBY

cat > config/initializers/permissions_policy.rb <<'RUBY'
# Rails.application.config.permissions_policy do |policy|
# end
RUBY

cat > config/initializers/inflections.rb <<'RUBY'
# Inflections
RUBY

cat > config/initializers/content_security_policy.rb <<'RUBY'
# CSP config
RUBY

cat > config/environments/test.rb <<'RUBY'
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
RUBY

cat > config/environments/production.rb <<'RUBY'
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
RUBY

cat > config/environments/development.rb <<'RUBY'
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
end
RUBY

# DB
cat > db/schema.rb <<'RUBY'
ActiveRecord::Schema[7.1].define(version: 2026_08_16_010005) do
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
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'moderator'::character varying, 'user'::character varying]::text[])", name: "users_role_valid"
  end
  add_foreign_key "fraud_analyses", "books"
  add_foreign_key "review_analyses", "reviews"
  add_foreign_key "reviews", "books"
  add_foreign_key "reviews", "users"
  add_foreign_key "user_ban_logs", "users"
  add_foreign_key "user_ban_logs", "users", column: "actor_id"
end
RUBY

cat > db/seeds.rb <<'RUBY'
# Seeds idempotentes
RUBY

# Migrations
cat > db/migrate/20260816010000_create_users.rb <<'RUBY'
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
RUBY

cat > db/migrate/20260816010001_create_books.rb <<'RUBY'
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
RUBY

cat > db/migrate/20260816010002_create_reviews.rb <<'RUBY'
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
RUBY

cat > db/migrate/20260816010003_create_review_analyses.rb <<'RUBY'
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
RUBY

cat > db/migrate/20260816010004_create_fraud_analyses.rb <<'RUBY'
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
RUBY

cat > db/migrate/20260816010005_create_user_ban_logs.rb <<'RUBY'
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
RUBY

echo ">>> Proyecto Bibliotk v2 reconstruido con fixes senior."
echo ">>> Ejecuta: bundle install && bin/rails db:migrate && bundle exec rspec"
