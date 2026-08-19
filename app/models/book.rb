class Book < ApplicationRecord
  has_many :reviews, dependent: :destroy
  has_many :fraud_analyses, dependent: :destroy

  validates :title, :author, presence: true

  validates :valid_reviews_count,
            :valid_total_stars,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }

  def average_rating
    return nil if valid_reviews_count < 3

    (valid_total_stars.to_f / valid_reviews_count).round(1, half: :up)
  end

  def average_rating_label
    average_rating || "Reseñas Insuficientes"
  end

  def increment_valid_ratings!(stars)
    stars = Integer(stars)

    raise ArgumentError unless stars.between?(1, 5)

    self.class.where(id: id).update_all(
      [
        "valid_reviews_count = valid_reviews_count + 1, " \
        "valid_total_stars = valid_total_stars + ?",
        stars
      ]
    )
  end

  def decrement_valid_ratings!(stars)
    stars = Integer(stars)

    raise ArgumentError unless stars.between?(1, 5)

    self.class.where(id: id).update_all(
      [
        "valid_reviews_count = GREATEST(valid_reviews_count - 1, 0), " \
        "valid_total_stars = GREATEST(valid_total_stars - ?, 0)",
        stars
      ]
    )
  end

  def sync_valid_ratings!(old, new)
    old = Integer(old)
    new = Integer(new)

    raise ArgumentError unless old.between?(1, 5) && new.between?(1, 5)
    return if old == new

    self.class.where(id: id).update_all(
      [
        "valid_total_stars = GREATEST(valid_total_stars - ? + ?, 0)",
        old,
        new
      ]
    )
  end

  def reconcile_valid_ratings!
    valid = reviews
      .joins(:user)
      .where(users: { banned: false })

    update_columns(
      valid_reviews_count: valid.count,
      valid_total_stars: valid.sum(:stars)
    )
  end

  def user_review(user)
    return unless user

    reviews.find_by(user_id: user.id)
  end
end