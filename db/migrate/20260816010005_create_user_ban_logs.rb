class CreateUserBanLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :user_ban_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.text :reason
      t.timestamps
    end
  end
end
