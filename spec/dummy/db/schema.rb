# encoding: UTF-8
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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130203095901) do

  create_table :turkee_tasks do |t|
    t.string   "hit_url"
    t.boolean  "sandbox"
    t.string   "task_type"
    t.text     "hit_title"
    t.text     "hit_description"
    t.string   "hit_id"
    t.decimal  "hit_reward", :precision => 10, :scale => 2
    t.integer  "hit_num_assignments"
    t.integer  "hit_lifetime"
    t.string   "form_url"
    t.integer  "completed_assignments", :default => 0
    t.boolean  "complete"
    t.boolean  "expired"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer  "turkee_flow_id"
    t.integer  "hit_duration"
  end

  create_table :surveys do |t|
    t.string :answer
  end

  create_table :turkee_studies do |t|
    t.integer :turkee_task_id
    t.string :feedback
  end

end
