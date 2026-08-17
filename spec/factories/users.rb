FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Usuario #{n}" }
    sequence(:email) { |n| "usuario#{n}@bibliotk.test" }
    password { "123456" }
    password_confirmation { "123456" }
    role { "user" }
    banned { false }

    trait :admin do
      role { "admin" }
    end

    trait :moderator do
      role { "moderator" }
    end

    trait :banned do
      banned { true }
    end
  end
end
