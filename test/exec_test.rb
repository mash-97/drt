# frozen_string_literal: true

require 'test_helper'

# ENSURE test/tmp dir for test purpose
TEST_TMP_PATH = File.join(File.absolute_path(File.dirname(__FILE__)), 'tmp')
unless Dir.exist?(TEST_TMP_PATH)
  Dir.mkdir(TEST_TMP_PATH)
  File.new(File.join(TEST_TMP_PATH, 'test.tst'), 'w+').close
end


class DrtTest < Test::Unit::TestCase
  include DRT

  test 'VERSION' do
    assert do
      ::Drt.const_defined?(:VERSION)
    end
  end

  test 'Test get student info method' do 
    puts(::DRT.get_student_info("181-15-965"))
    puts(::DRT.get_student_info("181-15-0"))
  end
end
