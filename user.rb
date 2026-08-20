class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy
  has_many :ban_logs, class_name: "UserBanLog", foreign_key: :user_id, inverse_of: :user, dependent: :destroy
  has_many :user_ban_logs, class_name: "UserBanLog", foreign_key: :user_id, inverse_of: :user, dependent: :destroy
  has_many :ban_actions, class_name: "UserBanLog", foreign_key: :actor_id, inverse_of: :actor, dependent: :nullify

  def admin?; role.to_s == "admin"; end
  def banned?; !!banned; end
  def can_review?; !banned?; end

  def ban_by!(admin_user, reason: nil)
    raise ArgumentError, "Solo ADMIN puede banear" unless admin_user&.admin?
    raise ArgumentError, "No puedes banearte a ti mismo" if admin_user.id == id
    transaction do
      update!(banned: true)
      UserBanLog.create!(user: self, actor: admin_user, action: 'banned', reason: reason)
    end
    UpdateBookRatingsOnUserBanJob.perform_later(id)
  end

  def unban_by!(admin_user)
    raise ArgumentError, "Solo ADMIN puede banear" unless admin_user&.admin?
    transaction do
      update!(banned: false)
      UserBanLog.create!(user: self, actor: admin_user, action: 'unbanned')
    end
    UpdateBookRatingsOnUserBanJob.perform_later(id)
  end
end
