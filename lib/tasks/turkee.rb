require 'rake'
require 'turkee'

namespace :turkee do
  desc "Post your form to Mechanical Turk (HIT). Task takes the application's host URL, HIT title, HIT description, model name, number of responses, reward for each response, number of days the HIT should be valid, and number of hours a worker has to complete the HIT."
  task :post_hit, [:host, :title, :description, :model, :num_assignments, :reward, :lifetime] => :environment do |t, args|
    hit = Turkee::TurkeeTask.create_hit(args[:host],args[:title], args[:description], args[:model],
                                        args[:num_assignments], args[:reward], args[:lifetime])
    puts "Hit created ( #{hit.hit_url} )."
  end

  desc "Retrieve all results from Mechanical Turk for all open HITs."
  task :get_all_results => :environment do
    Turkee::TurkeeTask.process_hits
  end

end
