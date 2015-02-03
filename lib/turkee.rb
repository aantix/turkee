require 'rubygems'
require 'action_view'
require 'helpers/turkee_forms_helper'
require 'models/turkee_imported_assignment'
require 'models/upc_task'
require 'models/categorize_task'

ActionView::Base.send :include, Turkee::TurkeeFormHelper
