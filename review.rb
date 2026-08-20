class Review < ApplicationRecord
  belongs_to :user
  belongs_to :book

  validates :stars, presence: true, inclusion: { in: 1..5 }
  validates :content, length: { maximum: 1000 }, allow_blank: true
  validates :user_id, uniqueness: { scope: :book_id, message: "ya reseñaste este libro" }
  validate :reviewer_can_review

  after_create_commit :add_to_rating
  after_update_commit :sync_rating_if_needed
  after_destroy_commit :remove_from_rating

  private

  def reviewer_can_review
    errors.add(:user, "baneado no puede reseñar") if user && !user.can_review?
  end

  def add_to_rating
    return if user&.banned?
    book.increment_valid_ratings!(stars)
  end

  def sync_rating_if_needed
    return unless saved_change_to_stars?
    old_stars, new_stars = saved_change_to_stars
    return if user&.banned?
    book.sync_valid_ratings!(old_stars, new_stars)
  end

  def remove_from_rating
    return if user&.banned?
    book.decrement_valid_ratings!(stars)
  end
end
