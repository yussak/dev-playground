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

ActiveRecord::Schema[8.1].define(version: 2026_06_16_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.datetime "created_at", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", default: 1, null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_variant_id"], name: "index_cart_items_on_cart_id_and_product_variant_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_variant_id"], name: "index_cart_items_on_product_variant_id"
  end

  create_table "carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_carts_on_user_id", unique: true
  end

  create_table "coupon_uses", force: :cascade do |t|
    t.bigint "coupon_id", null: false
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.string "status", default: "unused", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["coupon_id", "user_id"], name: "index_coupon_uses_on_coupon_id_and_user_id", unique: true
    t.index ["coupon_id"], name: "index_coupon_uses_on_coupon_id"
    t.index ["order_id"], name: "index_coupon_uses_on_order_id"
    t.index ["user_id"], name: "index_coupon_uses_on_user_id"
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "discount_type", null: false
    t.integer "discount_value", null: false
    t.datetime "expires_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
    t.index ["product_id"], name: "index_coupons_on_product_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.string "product_name", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", null: false
    t.string "size"
    t.integer "unit_price", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "discount_amount", default: 0, null: false
    t.string "order_number", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "product_images", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.text "url", null: false
    t.index ["product_id"], name: "index_product_images_on_product_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "price", null: false
    t.bigint "product_id", null: false
    t.string "size"
    t.datetime "updated_at", null: false
    t.index ["product_id", "color"], name: "idx_product_variants_color_only", unique: true, where: "((size IS NULL) AND (color IS NOT NULL))"
    t.index ["product_id", "size", "color"], name: "idx_product_variants_size_and_color", unique: true, where: "((size IS NOT NULL) AND (color IS NOT NULL))"
    t.index ["product_id", "size"], name: "idx_product_variants_size_only", unique: true, where: "((size IS NOT NULL) AND (color IS NULL))"
    t.index ["product_id"], name: "idx_product_variants_no_axis", unique: true, where: "((size IS NULL) AND (color IS NULL))"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_products_on_user_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_stocks_on_product_variant_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "product_variants", on_delete: :cascade
  add_foreign_key "carts", "users"
  add_foreign_key "coupon_uses", "coupons", on_delete: :cascade
  add_foreign_key "coupon_uses", "orders"
  add_foreign_key "coupon_uses", "users"
  add_foreign_key "coupons", "products", on_delete: :cascade
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants", on_delete: :nullify
  add_foreign_key "orders", "users"
  add_foreign_key "product_images", "products", on_delete: :cascade
  add_foreign_key "product_variants", "products", on_delete: :cascade
  add_foreign_key "products", "users"
  add_foreign_key "stocks", "product_variants", on_delete: :cascade
end
