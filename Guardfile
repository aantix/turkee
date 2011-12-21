guard 'spork', :rspec_env => { 'RAILS_ENV' => 'test' } do
  watch('spec/spec_helper.rb')
end


guard 'rspec', :version => 2, :cli => "--drb" do
  watch(%r{^spec/.+_spec\.rb$})

  # lib/
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
end

