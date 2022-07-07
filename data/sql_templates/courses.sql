		SELECT 
			semester_results.course_id,
			semester_results.custom_course_id,
			semester_results.course_title,
			COUNT(semester_results.course_id)
		FROM
			semester_results
		WHERE 
			semester_results.student_id = "191-15-1044"
		GROUP BY
			semester_results.custom_course_id,
			semester_results.course_id,
			semester_results.course_title
		HAVING 
			COUNT(semester_results.course_title) >= 1
		ORDER BY
			semester_results.custom_course_id;