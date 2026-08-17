class RatingReconciliationJob < ApplicationJob; queue_as :default; def perform; Book.find_each{|b| ReconcileBookRatingJob.perform_later(b.id)}; end; end
