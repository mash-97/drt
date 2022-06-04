# frozen_string_literal: true

require 'active_record'
# DRT module
module DRT
  # DRT Databse Migrator
  class DRTMigrator < ActiveRecord::Migration[5.2]
    def up

      # create `students` table if not exists
      unless table_exists?(:students)
        create_table(:students, id: false) do |table|
          table.column(:student_id, :string, primary_key: true)
          table.column(:student_name, :string)
          table.column(:campus_name, :string)
          table.column(:batch_no, :integer)
          table.column(:program_short_name, :string)
          table.column(:department_short_name, :string)
          table.column(:faculty_short_name, :string)
          table.column(:shift, :string)
        end
      end

      # create `semester_results` table if not exists
      unless table_exists?(:semester_results)
        create_table(:semester_results) do |table|
          table.column(:semester_id, :string)
          table.column(:semester_name, :string)
          table.column(:semester_year, :integer)
          table.column(:student_id, :string)
          table.column(:course_id, :string)
          table.column(:custom_course_id, :string)
          table.column(:course_title, :string)
          table.column(:total_credit, :float)
          table.column(:point_equivalent, :float)
          table.column(:grade_letter, :string)
        end
      end
    end
  end
end
