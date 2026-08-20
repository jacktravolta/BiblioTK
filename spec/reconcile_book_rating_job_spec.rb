require "rails_helper"

RSpec.describe ReconcileBookRatingJob, type: :job do
  describe "#perform" do
    it "reconcilia los contadores excluyendo usuarios baneados" do
      book = create(:book)

      valid_user = create(:user)
      banned_user = create(:user)

      create(
        :review,
        user: valid_user,
        book: book,
        stars: 5
      )

      create(
        :review,
        user: banned_user,
        book: book,
        stars: 2
      )

      # Simulamos contadores corruptos.
      book.update!(
        valid_reviews_count: 99,
        valid_total_stars: 99
      )

      banned_user.update!(banned: true)

      described_class.perform_now(book.id)

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end

    it "es idempotente" do
      book = create(:book)
      user = create(:user)

      create(
        :review,
        user: user,
        book: book,
        stars: 4
      )

      book.update!(
        valid_reviews_count: 0,
        valid_total_stars: 0
      )

      described_class.perform_now(book.id)

      book.reload

      first_count = book.valid_reviews_count
      first_stars = book.valid_total_stars

      described_class.perform_now(book.id)

      book.reload

      expect(book.valid_reviews_count).to eq(first_count)
      expect(book.valid_total_stars).to eq(first_stars)
      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(4)
    end

    it "no falla si el libro no existe" do
      expect {
        described_class.perform_now(-999_999)
      }.not_to raise_error
    end
  end
end
