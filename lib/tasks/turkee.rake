namespace :turkee do
  desc "Post your form to Mechanical Turk (HIT). Task takes model name, number of reponses, reward for each response, and number of days the HIT should be valid."
  task :post_hit, :model, :num_assignments, :reward, :lifetime  do |t, args|
    # args[:model]
    # args[:num_assignments]
    # args[:reward]
    # args[:lifetime]
  end

  desc "Retrieve all results from Mechanical Turk for all posted HITs."
  task :get_all_results do

  end

end
