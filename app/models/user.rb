class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy
  has_many :user_ban_logs, dependent: :destroy
  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  def admin?; role == 'admin'; end
  def ban_by!(by_user, reason: nil)
    raise ArgumentError, "No puedes banearte a ti mismo" if by_user.id == id
    raise ArgumentError, "Solo ADMIN puede banear" unless by_user.admin?
    transaction do
      update!(banned: true)
      user_ban_logs.create!(
        actor_id: by_user.id,
        banned_by_id: by_user.id,
        action: "banned",
        reason: reason || "Spam"
      )
    end
    UpdateBookRatingsOnUserBanJob.perform_later(id)
  end
  def unban_by!(by_user)
    raise ArgumentError, "Solo ADMIN puede desbanear" unless by_user.admin?
    update!(banned: false)
  end
end
