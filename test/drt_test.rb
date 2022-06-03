# frozen_string_literal: true

require 'test_helper'

# ENSURE test/tmp dir for test purpose
TEST_TMP_PATH = File.join(File.absolute_path(File.dirname(__FILE__)), 'tmp')
unless Dir.exist?(TEST_TMP_PATH)
  Dir.mkdir(TEST_TMP_PATH)
  File.new(File.join(TEST_TMP_PATH, 'test.tst'), 'w+').close
end

class C < ActiveRecord::Migration[5.2]
  def up
    puts('==> C UP: Migration Attempt')
    unless table_exists?(:tests)
      puts('Creating tests table!')
      create_table(:tests, id: false) do |table|
        table.column(:test_id, :string, primary_key: true)
        table.column(:title, :string, unique: true)
      end
    end

    unless table_exists?(:associated_tests)
      puts('Creating associated_tests table!')
      create_table(:associated_tests, id: false) do |table|
        table.column(:at_id, :string, primary_key: true)
        table.column(:name, :string)
        table.column(:test_id, :string)
      end
    end

    if column_exists?(:associated_tests,
                      :test_id) &&	column_exists?(:tests,
                                                  :test_id) && !foreign_key_exists?(:associated_tests, :tests)
      add_foreign_key(
        :associated_tests,
        :tests,
        column: :test_id,
        primary_key: :test_id
      )
    end
  end
end

class DrtTest < Test::Unit::TestCase
  include DRT

  test 'VERSION' do
    assert do
      ::Drt.const_defined?(:VERSION)
    end
  end

  test 'something useful' do
    assert_equal('3', '3')
  end

  test 'Test requesting student info' do
    si = ::DRT.request_student_info('181-15-955')
    assert(si['studentName'], 'Mashiur Rahman')
    assert(::DRT.public_methods.include?(:request_student_info))
  end
  test 'Test requesting student result' do
    sr = ::DRT.request_student_result('181-15-955', 221)
    assert_equal(sr.length, 5)
    assert(::DRT.public_methods.include?(:request_student_result))
  end

  test 'Test Database Connection Through Active Record' do
    db_path = File.join(TEST_TMP_PATH, 'test.db')
    log_path = File.join(TEST_TMP_PATH, 'test.log')
    assert(DB_CONNECTION_GEN.call(db_path, log_path))

    connection = ActiveRecord::Base.connection
    C.migrate(:up)
    assert(ActiveRecord::Base.connection.tables.length >= 2)
    assert((connection.column_exists?(:associated_tests, :test_id) and connection.column_exists?(:tests, :test_id)))
    assert(connection.foreign_key_exists?(:associated_tests, :tests))
  end
end
