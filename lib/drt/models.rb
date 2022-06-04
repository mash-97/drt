# frozen_string_literal: true

require 'active_record'
# DRT module
module DRT
  # DRT Databse Migrator
  class Student < ActiveRecord::Base
    has_many :semester_results
  end

  class SemesterResult < ActiveRecord::Base
    belongs_to :student
  end
end
