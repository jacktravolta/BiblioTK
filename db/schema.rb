# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_08_16_010005) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "books", force: :cascade do |t|
    t.string "title", null: false
    t.string "author", null: false
    t.integer "valid_reviews_count", default: 0, null: false
    t.integer "valid_total_stars", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "valid_reviews_count >= 0", name: "books_valid_count_nonneg"
    t.check_constraint "valid_total_stars >= 0", name: "books_valid_stars_nonneg"
  end

  create_table "fraud_analyses", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.boolean "fraude", null: false
    t.float "confianza"
    t.text "razon"
    t.integer "reviews_analyzed", default: 0, null: false
    t.string "model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id"], name: "index_fraud_analyses_on_book_id"
  end

  create_table "review_analyses", force: :cascade do |t|
    t.bigint "review_id", null: false
    t.string "sentimiento"
    t.string "resumen"
    t.float "confianza"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["review_id"], name: "index_review_analyses_on_review_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.integer "stars", null: false
    t.text "content"
    t.bigint "user_id", null: false
    t.bigint "book_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "created_at"], name: "index_reviews_on_book_id_and_created_at"
    t.index ["book_id"], name: "index_reviews_on_book_id"
    t.index ["user_id", "book_id"], name: "index_reviews_on_user_id_and_book_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.check_constraint "stars >= 1 AND stars <= 5", name: "reviews_stars_1_5"
  end

  create_table "user_ban_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.text "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_user_ban_logs_on_actor_id"
    t.index ["user_id"], name: "index_user_ban_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "user", null: false
    t.boolean "banned", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["banned"], name: "index_users_on_banned"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying, 'moderator'::character varying, 'user'::character varying]::text[])", name: "users_role_valid"
  end

  add_foreign_key "fraud_analyses", "books"
  add_foreign_key "review_analyses", "reviews"
  add_foreign_key "reviews", "books"
  add_foreign_key "reviews", "users"
  add_foreign_key "user_ban_logs", "users"
  add_foreign_key "user_ban_logs", "users", column: "actor_id"
end
