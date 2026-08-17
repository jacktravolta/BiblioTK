class User < ApplicationRecord
  has_secure_password; ROLES=%w[admin moderator user].freeze
  has_many :reviews, dependent: :destroy; has_many :user_ban_logs, dependent: :destroy; has_many :ban_actions, class_name:"UserBanLog", foreign_key: :actor_id, dependent: :restrict_with_exception, inverse_of: :actor
  before_validation :set_default_role, on: :create; before_save :downcase_email
  validates :name, presence:true, length:{in:2..50}; validates :email, presence:true, format:{with: URI::MailTo::EMAIL_REGEXP}; validates :password, length:{minimum:6}, allow_nil:true; validates :role, inclusion:{in: ROLES}; scope :banned, ->{where(banned:true)}
  def admin?; role=="admin"; end; def moderator?; role=="moderator"; end; def user?; role=="user"; end; def can_moderate?; admin?||moderator?; end; def can_manage_users?; admin?; end; def can_review?; !banned? && ROLES.include?(role); end
  def ban_by!(actor, reason:nil); raise ArgumentError,"Solo ADMIN puede banear" unless actor&.admin?; raise ArgumentError,"No puedes banearte a ti mismo" if actor.id==id; was=false; transaction do; with_lock do; was=banned?; unless was; update!(banned:true); user_ban_logs.create!(actor:actor,action:"banned",reason:reason); end; end; end; ::UpdateBookRatingsOnUserBanJob.perform_later(id) unless was; end
  def unban_by!(actor, reason:nil); raise ArgumentError,"Solo ADMIN puede desbanear" unless actor&.admin?; was=false; transaction do; with_lock do; was=banned?; if was; update!(banned:false); user_ban_logs.create!(actor:actor,action:"unbanned",reason:reason); end; end; end; ::UpdateBookRatingsOnUserBanJob.perform_later(id) if was; end
  private; def set_default_role; self.role||="user"; end; def downcase_email; self.email=email.to_s.strip.downcase; end
end
