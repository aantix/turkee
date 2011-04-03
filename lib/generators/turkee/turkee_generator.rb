require 'rails/generators'
require 'rails/generators/migration'

class TurkeeGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  
  # Implement the required interface for Rails::Generators::Migration.
  # taken from http://github.com/rails/rails/blob/master/activerecord/lib/generators/active_record.rb
  def self.next_migration_number(dirname)
    if ActiveRecord::Base.timestamped_migrations
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    else
      "%.3d" % (current_migration_number(dirname) + 1)
    end
  end

  source_root File.expand_path("../templates", __FILE__)

  desc "Creates initializer and migrations."
  
  def create_initializer
    initializer("turkee.rb") do
      AWSACCESSKEYID      = 'XXXXXXXXXXXXXXXXXX'
      AWSACCESSKEY        = 'YYYYYYYYYYYYYYYYYYYYYYYYYYYY'
      RTurk::logger.level = Logger::DEBUG
      RTurk.setup(AWSACCESSKEYID, AWSACCESSKEY, :sandbox => (Rails.env == 'production' ? false : true))
    end
  end
  
  def create_migrations
    migration_template "turkee_migration.rb.erb", "db/migrate/create_turkee_tasks.rb"
    
    # Need this sleep so that we don't get the same migration timestamp for both migrations
    sleep 1
    
    migration_template "turkee_imported_assignments.rb.erb", "db/migrate/create_turkee_imported_assignments.rb"
  end
end