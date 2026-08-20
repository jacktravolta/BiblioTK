require "rails_helper"

RSpec.describe "Review concurrency",
               type: :model,
               use_transactional_fixtures: false do
  self.use_transactional_tests = false

  describe "duplicate review race condition" do
    it "permite solo una review para el mismo usuario y libro" do
      book = create(:book)

      user = create(
        :user,
        email: "race-#{SecureRandom.hex(8)}@bibliotk.test"
      )

      results = Queue.new
      threads = []

      200.times do |i|
        threads << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              book_record = Book.find(book.id)
              user_record = User.find(user.id)

              review = Review.create!(
                user: user_record,
                book: book_record,
                stars: 5,
                content: "Concurrent attempt #{i}"
              )

              results << [:success, review.id]

            rescue ActiveRecord::RecordInvalid,
                   ActiveRecord::RecordNotUnique => e

              results << [:rejected, e.class.name]
            end
          end
        end
      end

      threads.each(&:join)

      successes = []
      rejected = []

      until results.empty?
        result = results.pop(true) rescue nil
        break unless result

        if result.first == :success
          successes << result
        else
          rejected << result
        end
      end

      book.reload

      expect(successes.size).to eq(1)
      expect(rejected.size).to eq(199)

      expect(book.reviews.count).to eq(1)
      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)

      expect(book.reviews.sum(:stars)).to eq(5)
    end
  end
end
