require 'rubygems'
require 'action_view'
require 'helpers/turkee_forms_helper'
require 'models/turkee_task'

ActionView::Base.send :include, Turkee::TurkeeFormHelper
