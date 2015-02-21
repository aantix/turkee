require 'rubygems'
require 'action_view'
require 'helpers/turkee_forms_helper'
require 'models/turkee_base'
require 'models/turkee_task'
require 'models/turkee_assignment'

ActionView::Base.send :include, Turkee::TurkeeFormHelper
