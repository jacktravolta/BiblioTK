require "rails_helper"
RSpec.describe "User ban rating flow", type: :model do
  include ActiveJob::TestHelper
  it "excluye las reviews del usuario baneado después de reconciliar" do
    admin = create(:user, :admin)
    valid_user = create(:user)
    user_to_ban = create(:user)
    book = create(:book)
    create(:review, user: valid_user, book: book, stars: 5)
    create(:review, user: user_to_ban, book: book, stars: 2)
    user_to_ban.ban_by!(admin, reason: "Spam")
    ReconcileBookRatingJob.perform_now(book.id)
    book.reload
    expect(book.valid_reviews_count).to eq(1)
    expect(book.valid_total_stars).to eq(5)
    expect(book.average_rating).to be_nil
    expect(book.average_rating_label).to eq("Reseñas Insuficientes")
  end
  it "mantiene el rating correcto si la reconciliación se ejecuta varias veces (idempotente)" do
    admin = create(:user, :admin)
    valid_user = create(:user)
    user_to_ban = create(:user)
    book = create(:book)
    create(:review, user: valid_user, book: book, stars: 4)
    create(:review, user: user_to_ban, book: book, stars: 1)
    user_to_ban.ban_by!(admin, reason: "Spam")
    3.times { ReconcileBookRatingJob.perform_now(book.id) }
    book.reload
    expect(book.valid_reviews_count).to eq(1)
  end
end
