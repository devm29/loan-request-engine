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

ActiveRecord::Schema.define(version: 2026_09_23_120100) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "loan_requests", force: :cascade do |t|
    t.string "address", null: false
    t.integer "loan_term", null: false
    t.integer "purchase_price", null: false
    t.integer "repair_budget", null: false
    t.integer "arv", null: false
    t.string "first_name", null: false
    t.string "last_name"
    t.string "email", null: false
    t.string "phone", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "product_code", default: "fix_and_flip", null: false
    t.string "status", default: "submitted", null: false
    t.string "reference", null: false
    t.string "request_fingerprint", null: false
    t.jsonb "explanation"
    t.datetime "delivered_at"
    t.string "failure_reason"
    t.index ["email"], name: "index_loan_requests_on_email"
    t.index ["reference"], name: "index_loan_requests_on_reference", unique: true
    t.index ["request_fingerprint"], name: "index_loan_requests_on_request_fingerprint", unique: true
    t.index ["status", "created_at"], name: "index_loan_requests_undelivered", where: "((status)::text <> 'delivered'::text)"
    t.check_constraint "(loan_term > 0) AND (loan_term <= 36)", name: "loan_term_range"
    t.check_constraint "arv > 0", name: "arv_positive"
    t.check_constraint "purchase_price > 0", name: "purchase_price_positive"
    t.check_constraint "repair_budget > 0", name: "repair_budget_positive"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
