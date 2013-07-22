source 'http://rubygems.org'

gemspec

rails_version = ENV["RAILS_VERSION"] || "default"

rails = case rails_version
when "master"
  {github: "rails/rails"}
when "default"
  "~> 4.0.0"
else
  "~> #{rails_version}"
end
