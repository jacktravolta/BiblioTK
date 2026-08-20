class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy
  has_many :user_ban_logs, dependent: :destroy

  validates :email, presence: true, uniqueness: true

  def admin?
    role == "admin"
  end

  def banned?
    !!self[:banned]
  end

  def ban_by!(by_user, _ = nil)
    transaction do
      update!(banned: true)
      user_ban_logs.create!(actor_id: by_user.id, action: "banned")
      reviews.includes(:book).find_each { |r| r.book.decrement_valid_ratings!(r.stars) }
    end
  end

  def unban_by!(by_user, _ = nil)
    transaction do
      update!(banned: false)
      user_ban_logs.create!(actor_id: by_user.id, action: "unbanned")
      reviews.includes(:book).find_each { |r| r.book.increment_valid_ratings!(r.stars) }
    end
  end
end
