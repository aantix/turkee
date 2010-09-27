namespace :turkee do
  desc "Post your form to Mechanical Turk (HIT). Task takes HIT title, HIT description, model name, number of responses, reward for each response, and number of days the HIT should be valid."
  task :post_hit, :title, :description, :model, :num_assignments, :reward, :lifetime  do |t, args|
    # args[:title]
    # args[:description]
    # args[:model]
    # args[:num_assignments]
    # args[:reward]
    # args[:lifetime]

    TurkeeTask.create_hit(args[:title], args[:description], args[:model],
                          args[:num_assignments], args[:reward], args[:lifetime])
  end

  desc "Retrieve all results from Mechanical Turk for all open HITs."
  task :get_all_results do
    TurkeeTask.process_hits
  end

end
