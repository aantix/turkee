module Turkee

  module TurkeeFormHelper
    def turkee_form_for(record, params, options = {}, &proc)
      raise ArgumentError, "turkee_form_for now requires that you pass in the entire params hash, instead of just the assignmentId value. " unless params.is_a?(Hash)

      options.merge!({:url => mturk_url})

      capture do
        form_for record, options do |f|
          params.each do |k,v|
            unless ['action','controller'].include?(k) || !v.is_a?(String)
              concat hidden_field_tag(k, v)
              cookies[k] = v
            end
          end

          ['assignmentId', 'workerId', 'hitId'].each do |k|
            concat hidden_field_tag(k, cookies[k]) if !params.has_key?(k) && cookies.has_key?(k)
          end

          concat(capture(f, &proc))
        end
      end
    end

    # Returns the external Mechanical Turk url used to post form data based on whether RTurk is cofigured
    #   for sandbox use or not.
    def mturk_url
      RTurk.sandbox? ? "https://workersandbox.mturk.com/mturk/externalSubmit" : "https://www.mturk.com/mturk/externalSubmit"
    end

    # Returns whether the form fields should be disabled or not (based on the assignment_id)
    def self.disable_form_fields?(assignment)
      assignment_id = assignment.is_a?(Hash) ? assignment[:assignmentId] : assignment
      (assignment_id.nil? || assignment_id == 'ASSIGNMENT_ID_NOT_AVAILABLE')
    end
  end

end
