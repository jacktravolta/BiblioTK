class UserBanLog < ApplicationRecord; belongs_to :user; belongs_to :actor, class_name:"User", inverse_of: :ban_actions; end
