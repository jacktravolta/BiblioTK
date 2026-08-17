class Review < ApplicationRecord
  belongs_to :user; belongs_to :book; has_one :review_analysis, dependent: :destroy
  validates :stars, presence:true, inclusion:{in:1..5}; validates :content, length:{maximum:1000}, allow_blank:true; validates :user_id, uniqueness:{scope: :book_id, message:"ya reseñaste este libro"}
  validate :reviewer_can_review; after_create_commit :add_to_rating; after_update_commit :sync_rating, if: :saved_change_to_stars?; after_destroy_commit :remove_from_rating
  private; def reviewer_can_review; if user.nil?; errors.add(:user,"debe estar registrado"); elsif !user.can_review?; errors.add(:user,"baneado por spam no puede reseñar"); end; end; def add_to_rating; return if user&.banned?; book.increment_valid_ratings!(stars); end; def sync_rating; return if user&.banned?; o,n=saved_change_to_stars; book.sync_valid_ratings!(o,n); end; def remove_from_rating; return if user&.banned?; book.decrement_valid_ratings!(stars); end
end
