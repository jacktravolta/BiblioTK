class Review < ApplicationRecord
  belongs_to :book
  belongs_to :user

  validates :stars, presence: true, inclusion: { in: 1..5 }
  validates :content, length: { maximum: 1000 }, allow_blank: true
  validates :user_id, uniqueness: { scope: :book_id, message: "ya reseñaste este libro" }

  validate :reviewer_can_review

  after_create :add_to_rating
  after_update :update_rating_if_needed
  after_destroy :remove_from_rating

  private

  def reviewer_can_review
    errors.add(:base, "Usuario baneado no puede valorar") if user&.banned?
  end

  def add_to_rating
    return if user&.banned?
    book.increment_valid_ratings!(stars)
  end

  def update_rating_if_needed
    return if user&.banned?
    return unless saved_change_to_stars?
    old_stars, new_stars = saved_change_to_stars
    book.sync_valid_ratings!(old_stars, new_stars)
  end

  def remove_from_rating
    return if user&.banned?
    book.decrement_valid_ratings!(stars)
  end
end
