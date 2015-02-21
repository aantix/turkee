class TestTurkeeTask < Turkee::TurkeeTask
  class << self
    def expected_result_field
      "category"
    end

    def valid_assignment?(assignment)
      true
    end

    def host
      "https://retsku-mt.herokuapp.com"
    end

    def hit_title
      "Test turkee Task"
    end

    def hit_description
      "For turkee gem integration test"
    end

    def lifetime
      5 # days
    end

    def duration
      24 # hours
    end

    def reward
      0.1
    end

    def max_assignments
      1
    end

    def num_assignments
      1
    end

    def form_url(turkable, params)
      host + "/mt/retailer_products/#{turkable.id}/edit"
    end

    def create_hit(turkable, qualifications={})
      f_url = form_url(turkable, {})
      Turkee::TurkeeTask.create_hit(self.name, host, hit_title, hit_description, turkable, num_assignments,
                                    reward, lifetime, duration, f_url, qualifications)
    end
  end

  def turkable_key
    "retailer_product"
  end

  def update_target_object(data)
    turkable.update_attributes(data)
  end
end
