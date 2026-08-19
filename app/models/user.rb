class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy

  def admin?
    role.to_s == "admin"
  end

  def user?
    role.to_s != "admin"
  end

  def banned?
    !!banned
  end

  def can_review?
    !banned?
  end

  def ban_by!(admin_user, reason: nil)
    update!(banned: true)
    UpdateBookRatingsOnUserBanJob.perform_now(self.id)
  end

  def unban_by!(admin_user)
    update!(banned: false)
    UpdateBookRatingsOnUserBanJob.perform_now(self.id)
  end
end
