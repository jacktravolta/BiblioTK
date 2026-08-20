class User < ApplicationRecord
  has_secure_password
  has_many :reviews, dependent: :destroy
  has_many :user_ban_logs, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }

  def admin?
    role == 'admin'
  end

  def ban_by!(by_user, reason: nil)
    raise ArgumentError, "No puedes banearte a ti mismo" if by_user == self || by_user.id == id
    raise ArgumentError, "Solo ADMIN puede banear" unless by_user.admin?

    transaction do
      update!(banned: true)
      attrs = { banned_by: by_user }
      attrs[:reason] = reason if reason && UserBanLog.column_names.include?('reason')
      user_ban_logs.create!(attrs)
    end
    UpdateBookRatingsOnUserBanJob.perform_later(id)
  end

  def unban_by!(by_user)
    raise ArgumentError, "Solo ADMIN puede desbanear" unless by_user.admin?
    update!(banned: false)
    RatingReconciliationJob.perform_later if defined?(RatingReconciliationJob)
  end
end
