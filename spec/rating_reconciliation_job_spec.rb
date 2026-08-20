require "rails_helper"

RSpec.describe RatingReconciliationJob, type: :job do
  include ActiveJob::TestHelper

  describe "#perform" do
    it "encola una reconciliación para cada libro existente" do
      create_list(:book, 3)

      books = Book.all.to_a

      clear_enqueued_jobs

      described_class.perform_now

      jobs = enqueued_jobs.select do |job|
        job[:job] == ReconcileBookRatingJob
      end

      expect(jobs.size).to eq(books.size)

      book_ids = jobs.map do |job|
        job[:args].first
      end

      expect(book_ids).to contain_exactly(
        *books.map(&:id)
      )
    end

    it "no falla cuando no hay libros que procesar" do
      allow(Book).to receive(:find_each)

      clear_enqueued_jobs

      expect {
        described_class.perform_now
      }.not_to raise_error

      expect(
        enqueued_jobs.select do |job|
          job[:job] == ReconcileBookRatingJob
        end
      ).to be_empty
    end
  end
end
