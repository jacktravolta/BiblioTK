class FraudAnalysis < ApplicationRecord; belongs_to :book; scope :latest_first, ->{order(created_at: :desc)}; end
