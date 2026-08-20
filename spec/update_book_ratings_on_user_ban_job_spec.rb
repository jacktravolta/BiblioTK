require "rails_helper"

RSpec.describe UpdateBookRatingsOnUserBanJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    it "encola reconciliación para todos los libros reseñados por el usuario" do
      user = create(:user)

      book1 = create(:book)
      book2 = create(:book)
      book3 = create(:book)

      create(:review, user: user, book: book1, stars: 5)
      create(:review, user: user, book: book2, stars: 4)
      create(:review, user: user, book: book3, stars: 3)

      clear_enqueued_jobs

      described_class.perform_now(user.id)

      jobs = enqueued_jobs.select do |job|
        job[:job] == ReconcileBookRatingJob
      end

      expect(jobs.size).to eq(3)

      book_ids = jobs.map do |job|
        job[:args].first
      end

      expect(book_ids).to contain_exactly(
        book1.id,
        book2.id,
        book3.id
      )
    end

    it "no falla si el usuario no existe" do
      expect {
        described_class.perform_now(-999_999)
      }.not_to raise_error

      expect(enqueued_jobs).to be_empty
    end
  end
end
