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
      ::DRT.const_defined?(:VERSION)
    end
  end

  test 'Test get student info method' do
    assert(::DRT.get_student_info('181-15-933'))
  end
end

class DrtV1Test < Test::Unit::TestCase
  include DRT

  CONFIG = DRTV1::Config.new(
    File.join(TEST_TMP_PATH, 'drtv1_config.conf'),
    File.join(TEST_TMP_PATH, 'drtv1.db'),
    File.join(TEST_TMP_PATH, 'drtv1.log')
  )

  DRTV1_OBJ = DRTV1::DRT.new(CONFIG)

  test "Test there's a DRTV1" do
    assert ::Object.constants.include?(:DRTV1)
  end

  test 'Test update student info' do
    student = Student.find_by(student_id: '181-15-955')
    if student
      puts("Student found! #{student.inspect}")
      student.delete
    end

    assert(Student.find_by(student_id: '181-15-955').nil?)

    Student.new(
      DRTV1.get_student_info(
        '181-15-955',
        DRTV1_OBJ.logger,
        DRTV1_OBJ.faraday_connection
      )
    ).save

    student = Student.find_by(student_id: '181-15-955')
    assert(student)
    student.delete
    assert(Student.find_by(student_id: '181-15-955').nil?)
    DRTV1.update_student_info(
      '181-15-955',
      DRTV1_OBJ.logger,
      DRTV1_OBJ.faraday_connection
    )
    assert(Student.find_by(student_id: '181-15-955'))
  end

  test "Test semester result" do 
    assert(true)
  end
end
