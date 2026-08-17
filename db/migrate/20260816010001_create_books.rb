class CreateBooks < ActiveRecord::Migration[7.1]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :author, null: false
      t.integer :valid_reviews_count, null: false, default: 0
      t.integer :valid_total_stars, null: false, default: 0
      t.timestamps
    end
    add_check_constraint :books, "valid_reviews_count >= 0", name: "books_valid_count_nonneg"
    add_check_constraint :books, "valid_total_stars >= 0", name: "books_valid_stars_nonneg"
  end
end
