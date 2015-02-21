require 'webmock'
require 'vcr'

VCR.configure do |c|
 c.cassette_library_dir = 'vcr_cassettes'
 c.hook_into :webmock
 c.configure_rspec_metadata!
 c.default_cassette_options = { record: :new_episodes, match_requests_on: [:uri, :body, :method] }
end
