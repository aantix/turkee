namespace :turkee do
  desc "Post your form to Mechanical Turk (HIT)."
  task :posthits, :model, :num_hits, :reward do |t, args|
    # args[:model]
    # args[:num_hits]
  end

  desc "Retrieve all results from Mechanical Turk for all posted HITs."
  task :get_all_results do

  end

end
