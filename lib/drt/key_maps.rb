# frozen_string_literal: true

# DRT module
module DRT
  # DRT Databse Migrator
  STUDENT_INFO_KEY_MAP = {
    'student_id' => 'studentId',
    'student_name' => 'studentName',
    'campus_name' => 'campusName',
    'batch_no' => 'batchNo',
    'program_short_name' => 'programShortName',
    'department_short_name' => 'departmentShortName',
    'faculty_short_name' => 'facShortName',
    'shift' => 'shift'
  }

  SEMESTER_RESULT_KEY_MAP = {
    'semester_id' => 'semesterId',
    'semester_name' => 'semesterName',
    'semester_year' => 'semesterYear',
    'student_id' => 'studentId',
    'course_id' => 'courseId',
    'custom_course_id' => 'customCourseId',
    'course_title' => 'courseTitle',
    'total_credit' => 'totalCredit',
    'point_equivalent' => 'pointEquivalent',
    'grade_letter' => 'gradeLetter'
  }

  def self.parse_student_info(student_info)
    parsed_student_info = {}
    STUDENT_INFO_KEY_MAP.each_key{|k|
      parsed_student_info[k] = student_info[k]
    }
    return parsed_student_info
  end

  def self.parse_semester_result(semester_result)
    parsed_semester_result = {}
    SEMESTER_RESULT_KEY_MAP.each_key{|k|
      parsed_semester_result[k] = student_info[k]
    }
    return parsed_semester_result
  end 
end
