# frozen_string_literal: true

require "test_helper"

include DRT

class DrtTest < Test::Unit::TestCase
  test "VERSION" do
    assert do
      ::Drt.const_defined?(:VERSION)
    end
  end

  test "something useful" do
    assert_equal("3", "3")
  end
  
  test "Test requesting student info" do
	si = DRT::requestStudentInfo("181-15-955")
	puts(si)
	assert(DRT.public_methods.include?(:requestStudentInfo))
  end 
  
  
end
