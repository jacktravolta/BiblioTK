class UserBanLog < ApplicationRecord
  belongs_to :user, inverse_of: :ban_logs
  belongs_to :actor, class_name: "User", inverse_of: :ban_actions
end
