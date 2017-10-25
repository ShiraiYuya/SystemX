# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20171018090959) do

  create_table "amounts", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.date "date"
    t.integer "f_ship", default: 0
    t.integer "f_stored", default: 0
    t.integer "f_store", default: 0
    t.integer "z_ship", default: 0
    t.integer "z_stored", default: 0
    t.integer "z_store", default: 0
    t.integer "other_ship", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "f_pred", default: 0
    t.integer "z_pred", default: 0
    t.integer "other_pred", default: 0
  end

  create_table "materials", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "company"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_materials", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "product_id"
    t.integer "material_id"
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "company"
    t.string "name"
    t.integer "storage"
    t.integer "timelimit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
