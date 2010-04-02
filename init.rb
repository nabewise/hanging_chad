# Include hook code here
require 'hanging_chad'
ActiveRecord::Base.send(:extend, HangingChad::ClassMethods)
