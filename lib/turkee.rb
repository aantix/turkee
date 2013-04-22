require 'rubygems'
require 'action_view'
require 'helpers/turkee_forms_helper'
require 'models/turkee_imported_assignment'
require 'models/turkee_task'
require 'models/turkee_study'

ActionView::Base.send :include, Turkee::TurkeeFormHelper
