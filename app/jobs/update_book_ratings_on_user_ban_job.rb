class UpdateBookRatingsOnUserBanJob < ApplicationJob
  queue_as :default
  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user
    book_ids = Review.where(user_id: user.id).distinct.pluck(:book_id)
    Book.where(id: book_ids).find_each(&:reconcile_valid_ratings!)
  end
end
