#!/bin/bash
set -e
echo ">>> Aplicando fixes senior a Bibliotk..."

# 1. AiAnalyzer
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

# 2. Book
cat > app/models/book.rb <<'RUBY'
class Book < ApplicationRecord
  has_many :reviews, dependent: :destroy
  has_many :fraud_analyses, dependent: :destroy

  validates :title, :author, presence: true
  validates :valid_reviews_count, :valid_total_stars,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # FIX: retorna nil, no String. El label va en presenter/helper.
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

# 3. Review
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

# 4. User
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

  def set_default_role
    self.role ||= "user"
  end

  def downcase_email
    self.email = email.to_s.strip.downcase
  end
end
RUBY

# 5. ApplicationJob
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

echo ">>> Done. Archivos actualizados:"
echo " - app/services/ai_analyzer.rb"
echo " - app/models/book.rb"
echo " - app/models/review.rb"
echo " - app/models/user.rb"
echo " - app/jobs/application_job.rb"
echo ""
echo ">>> Ajuste en specs: cambia expectation de average_rating"
echo "  expect(book.average_rating).to eq(nil)  # antes 'Reseñas Insuficientes'"
echo "  expect(book.average_rating_label).to eq('Reseñas Insuficientes')"
echo ""
echo ">>> Ejecuta: bundle exec rspec"
