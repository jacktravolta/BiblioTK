class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "user"
      t.boolean :banned, null: false, default: false
      t.timestamps
    end
    add_index :users, "LOWER(email)", unique: true, name: "index_users_on_lower_email"
    add_index :users, :banned
    add_check_constraint :users, "role IN ('admin','moderator','user')", name: "users_role_valid"
  end
end
