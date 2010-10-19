class TurkeeGenerator < Rails::Generator::Base

  def manifest
    record do |m|
      m.migration_template "turkee_migration.rb.erb", File.join('db', 'migrate'), :migration_file_name => 'create_turkee_tasks'
      m.sleep 1   # Need this sleep so that we don't get the same migration timestamp for both migrations
      m.migration_template "turkee_imported_assignments.rb.erb", File.join('db', 'migrate'), :migration_file_name => 'create_turkee_imported_assignments'
    end
  end

  def banner
    %{Usage: #{$0} #{spec.name}\nCopies needed migrations to project.}
  end

end