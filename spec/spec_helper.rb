require 'rubygems'
require "bundler/setup" 

# require File.expand_path("../../config/environment", __FILE__)
require 'factory_girl'
require 'rspec'
require 'spork'
require 'growl'
  
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
  # This code will be run each time you run your specs.
  Dir["#{File.dirname(__FILE__)}/../lib/**/*.rb"].each {|f| require f}
  Dir["#{File.dirname(__FILE__)}/../lib/date_time/**/*.rb"].each {|f| require f}
  
  Dir["#{File.dirname(__FILE__)}/factories/**/*.rb"].each {|f| require f}
  Dir["#{File.dirname(__FILE__)}/../normalization/**/*.rb"].each {|f| require f}
  Dir["#{File.dirname(__FILE__)}/../transformation/**/*.rb"].each {|f| require f}
end