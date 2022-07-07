SELECT 
	semester_results.custom_course_id,
	semester_results.course_id,
	semester_results.course_title
FROM
	semester_results
WHERE 
	semester_results.student_id = "181-15-955";