module Turkee

  module TurkeeFormHelper
    def turkee_form_for(record, params, options = {}, &proc)
      raise ArgumentError, "turkee_form_for now requires that you pass in the entire params hash, instead of just the assignmentId value. " unless params.is_a?(Hash)

      options.merge!({:url => mturk_url})

      buffer = ''
      form_for record, options do |f|
        params.each do |k,v|
          unless ['action','controller'].include?(k) || !v.is_a?(String)
            buffer << hidden_field_tag(k, v)
            cookies[k] = v
          end
        end

        ['assignmentId', 'workerId', 'hitId'].each do |k|
          buffer << hidden_field_tag(k, cookies[k]) if !params.has_key?(k) && cookies.has_key?(k)
        end

        buffer << yield(f)
        buffer.html_safe
      end
    end

    def turkee_study(id = nil)
      task     = id.nil? ? Turkee::TurkeeTask.last : Turkee::TurkeeTask.find(id)
      study    = Turkee::TurkeeStudy.new
      disabled = Turkee::TurkeeFormHelper::disable_form_fields?(params[:assignmentId])

      if task.present?
        style =  "position: fixed; top: 120px; right: 30px; color: #FFF;"
        style << "width: 400px; height: 375px; z-index: 100; padding: 10px;"
        style << "background-color: rgba(0,0,0, 0.5); border: 1px solid #000;"
        div_for(task, :style => style) do
          content = content_tag(:h3, "DIRECTIONS")
          content << task.hit_description.html_safe
          content << '<hr/>'.html_safe
          content << turkee_form_for(study, params) do |f|
            buffer =  f.label(:feedback, "Feedback?:")
            buffer <<  f.text_area(:feedback, :rows => 3, :disabled => disabled)
            buffer << f.label(:gold_response, "Enter the fourth word from your above feedback :")
            buffer << f.text_field(:gold_response, :disabled => disabled)
            buffer << f.hidden_field(:turkee_task_id, :value => task.id)
            buffer << '<br/>'.html_safe
            buffer << f.submit('Submit', :disabled => disabled)
            buffer
          end.html_safe
          content
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
