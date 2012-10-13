require 'rubygems'
require "bundler/setup"

require 'factory_girl'
require 'rspec'
require 'spork'
require 'rails'
require 'rturk'
require 'lockfile'
require 'active_record'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
ActiveRecord::Schema.define(:version => 1) do
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
end


Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  FactoryGirl.find_definitions

  RSpec.configure do |config|
    # == Mock Framework
    # 
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    config.mock_with :rspec

    #config.fixture_path = "#{::Rails.root}/spec/fixtures"

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, comment the following line or assign false
    # instead of true.
    #config.use_transactional_fixtures = true
  end

end

Spork.each_run do
  $LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')
  Dir["#{File.dirname(__FILE__)}/../lib/**/*.rb"].each {|f| require f}
end