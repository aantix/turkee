guard 'spork', :cucumber_env => { 'RAILS_ENV' => 'test' }, :rspec_env => { 'RAILS_ENV' => 'test' } do
  watch('spec/spec_helper.rb')
end


guard 'rspec', :version => 2, :cli => "--drb" do
  watch(%r{^spec/.+_spec\.rb$})

  # lib/
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^lib/date_time/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }

  # lib/
  watch(%r{^normalization/(.+)\.rb$}) { |m| "spec/normalization/#{m[1]}_spec.rb" }
  watch(%r{^transformation/(.+)\.rb$})     { |m| "spec/transformation/#{m[1]}_spec.rb" }

end

