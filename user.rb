class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy

  def admin?
    role == "admin"
  end

  def ban_by!(admin, reason: nil)
    transaction do
      update!(banned: true)
      reviews.includes(:book).each do |review|
        review.book.decrement_valid_ratings!(review.stars)
      end
      FraudAnalysis.create!(user_id: id, admin_id: admin.id, action: "ban", reason: reason) rescue nil
    end
  end

  def unban_by!(admin)
    transaction do
      update!(banned: false)
      reviews.includes(:book).each do |review|
        review.book.increment_valid_ratings!(review.stars)
      end
    end
  end
end
