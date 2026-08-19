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
