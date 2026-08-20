FactoryBot.define do
  factory :book do
    sequence(:title) { |n| "Libro #{n}" }
    sequence(:author) { |n| "Autor #{n}" }
  end
end
