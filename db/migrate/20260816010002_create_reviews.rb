class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews do |t|
      t.integer :stars, null: false
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.references :book, null: false, foreign_key: true
      t.timestamps
    end
    add_check_constraint :reviews, "stars BETWEEN 1 AND 5", name: "reviews_stars_1_5"
    add_index :reviews, [:user_id, :book_id], unique: true
    add_index :reviews, [:book_id, :created_at]
  end
end
