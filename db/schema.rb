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

ActiveRecord::Schema.define(version: 20131229065333) do

  create_table "comments", force: true do |t|
    t.integer  "line"
    t.text     "text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "file_id"
    t.integer  "user_id"
  end

  add_index "comments", ["file_id"], name: "index_comments_on_file_id"

  create_table "files", force: true do |t|
    t.text    "path"
    t.integer "revision_id"
  end

  add_index "files", ["revision_id"], name: "index_files_on_revision_id"

  create_table "projects", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  add_index "projects", ["user_id"], name: "index_projects_on_user_id"

  create_table "public_keys", force: true do |t|
    t.text     "public_key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
  end

  add_index "public_keys", ["user_id"], name: "index_public_keys_on_user_id"

  create_table "revisions", force: true do |t|
    t.string   "commit_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "project_id"
  end

  add_index "revisions", ["project_id"], name: "index_revisions_on_project_id"

  create_table "users", force: true do |t|
    t.string   "provider"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
