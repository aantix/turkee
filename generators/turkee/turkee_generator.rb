class TurkeeGenerator < Rails::Generator::Base
  
  def initialize(*runtime_args)
    super
  end
  
  def manifest
    record do |m|
      m.directory File.join('public', 'javascripts')
      m.template 'turkee.js',   File.join('public', 'javascripts', 'turkee.js')
      m.migration_template "turkee_migration.rb.erb",File.join('db', 'migrate'), :migration_file_name => 'create_turkee_tasks'
  end
    
  protected
  
  def banner
    %{Usage: #{$0} #{spec.name}\nCopies turkee.js to public/javascripts/.}
  end
  
end