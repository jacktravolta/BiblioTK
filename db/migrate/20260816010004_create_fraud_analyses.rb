class CreateFraudAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :fraud_analyses do |t|
      t.references :book, null: false, foreign_key: true
      t.boolean :fraude, null: false
      t.float :confianza
      t.text :razon
      t.integer :reviews_analyzed, null: false, default: 0
      t.string :model
      t.timestamps
    end
  end
end
