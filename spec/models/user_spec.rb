require "rails_helper"

RSpec.describe User, type: :model do
  describe "#ban_by!" do
    it "banea un usuario y genera un log" do
      admin = create(:user, :admin)
      user = create(:user)

      user.ban_by!(
        admin,
        reason: "Spam"
      )

      user.reload

      expect(user.banned?).to be(true)
      expect(user.user_ban_logs.count).to eq(1)
      expect(user.user_ban_logs.last.action).to eq("banned")
    end

    it "no permite que un usuario se banee a sí mismo" do
      admin = create(:user, :admin)

      expect {
        admin.ban_by!(admin)
      }.to raise_error(
        ArgumentError,
        "No puedes banearte a ti mismo"
      )
    end

    it "no permite que un usuario normal banee" do
      user = create(:user)
      target = create(:user)

      expect {
        target.ban_by!(user)
      }.to raise_error(
        ArgumentError,
        "Solo ADMIN puede banear"
      )
    end
  end

  describe "rating después de un baneo" do
    it "excluye las reseñas del usuario baneado" do
      admin = create(:user, :admin)
      banned_user = create(:user)
      valid_user = create(:user)
      book = create(:book)

      create(
        :review,
        user: banned_user,
        book: book,
        stars: 2
      )

      create(
        :review,
        user: valid_user,
        book: book,
        stars: 5
      )

      expect {
        banned_user.ban_by!(
          admin,
          reason: "Spam"
        )
      }.not_to raise_error

      ReconcileBookRatingJob.perform_now(book.id)

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end
  end
end
