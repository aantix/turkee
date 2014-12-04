require 'active_record'

module Turkee
  class Base < ActiveRecord::Base
    self.abstract_class = true

    database = if ENV["DEPLOYED"] == "true"
      ENV['RETAILER_PRODUCT_QUERY_DATABASE_URL']
    else
      YAML::load(IO.read('config/external_database.yml'))["retailer_product_query_#{Rails.env}"]
    end

    establish_connection database
  end
end
