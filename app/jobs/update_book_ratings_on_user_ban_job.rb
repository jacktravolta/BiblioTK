class UpdateBookRatingsOnUserBanJob < ApplicationJob
  queue_as :default
  
  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user
    
    book_ids = Review.where(user_id: user.id).distinct.pluck(:book_id)
    
    book_ids.each do |book_id|
      ReconcileBookRatingJob.perform_later(book_id)
    end
  end
end
