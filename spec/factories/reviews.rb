FactoryBot.define do
  factory :review do
    association :user
    association :book
    stars { 5 }
    content { "Excelente libro" }
  end
end
