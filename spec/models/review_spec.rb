require "rails_helper"

RSpec.describe Review, type: :model do
  let(:book) { create(:book) }
  let(:user) { create(:user) }

  describe "validaciones" do
    it "permite una reseña de un usuario registrado" do
      review = build(
        :review,
        user: user,
        book: book,
        stars: 5
      )

      expect(review).to be_valid
    end

    it "impide una segunda reseña del mismo usuario para el mismo libro" do
      create(
        :review,
        user: user,
        book: book
      )

      duplicate = build(
        :review,
        user: user,
        book: book
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.full_messages.join(" ")).to include(
        "ya reseñaste este libro"
      )
    end

    it "impide reseñar a un usuario baneado" do
      user.update!(banned: true)

      review = build(
        :review,
        user: user,
        book: book
      )

      expect(review).not_to be_valid
    end

    it "valida estrellas entre 1 y 5" do
      review = build(
        :review,
        user: user,
        book: book,
        stars: 6
      )

      expect(review).not_to be_valid
    end
  end

  describe "rating O(1)" do
    it "incrementa los contadores al crear una reseña" do
      create(
        :review,
        user: user,
        book: book,
        stars: 5
      )

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end

    it "actualiza las estrellas sin cambiar la cantidad" do
      review = create(
        :review,
        user: user,
        book: book,
        stars: 3
      )

      review.update!(stars: 5)

      book.reload

      expect(book.valid_reviews_count).to eq(1)
      expect(book.valid_total_stars).to eq(5)
    end

    it "actualiza los contadores al eliminar una reseña" do
      review = create(
        :review,
        user: user,
        book: book,
        stars: 5
      )

      review.destroy!

      book.reload

      expect(book.valid_reviews_count).to eq(0)
      expect(book.valid_total_stars).to eq(0)
    end
  end
end
