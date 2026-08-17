class ReconcileBookRatingJob < ApplicationJob; queue_as :default; def perform(id); b=Book.find_by(id:id); return unless b; b.with_lock{ b.reconcile_valid_ratings! }; end; end
