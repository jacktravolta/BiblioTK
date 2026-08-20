require "rails_helper"
RSpec.describe Book, type: :model do
  describe "#average_rating" do
    it "devuelve nil con menos de 3 reseñas" do
      book = create(:book)
      expect(book.average_rating).to be_nil
      expect(book.average_rating_label).to eq("Reseñas Insuficientes")
    end
    it "calcula el promedio cuando hay 3 o más reseñas" do
      book = create(:book)
      book.update!(valid_reviews_count: 3, valid_total_stars: 12)
      expect(book.average_rating).to eq(4.0)
    end
    it "redondea half-up correctamente (borde 3.25->3.3)" do
      book = create(:book)
      book.update!(valid_reviews_count: 4, valid_total_stars: 13)
      expect(book.average_rating).to eq(3.3)
    end
    it "redondea borde inferior 3.24->3.2" do
      book = create(:book)
      book.update!(valid_reviews_count: 5, valid_total_stars: 16)
      expect(book.average_rating).to eq(3.2)
    end
  end
end
