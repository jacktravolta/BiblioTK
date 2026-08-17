FactoryBot.define do
  factory :corporate_user, class: 'User' do
    sequence(:name) { |n| "Tester Corp #{n}" }
    sequence(:email) { |n| "corp#{n}@bibliotk.cl" }
    password { "12345678" }
    role { "user" }
    banned { false }
  end

  factory :diverse_review, class: 'Review' do
    stars { [5,5,5,4,4,3,2,1].sample }
    content do
      {
        5 => "Excelente obra corporativa, muy recomendable.",
        4 => "Muy buen libro, con detalles menores.",
        3 => "Correcto, cumple sin sorprender.",
        2 => "Regular, necesita mejoras.",
        1 => "Deficiente, no recomendable."
      }[stars]
    end
    association :user, factory: :corporate_user
    association :book
  end
end
