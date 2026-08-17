class CreateReviewAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :review_analyses do |t|
      t.references :review, null: false, foreign_key: true
      t.string :sentimiento
      t.string :resumen
      t.float :confianza
      t.timestamps
    end
  end
end
