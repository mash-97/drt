

create view courses as SELECT 
	semester_results.custom_course_id,
	semester_results.course_id,
	semester_results.course_title,
	semester_results.total_credit,
	COUNT(semester_results.course_id)
FROM
	semester_results
WHERE 
	semester_results.student_id = "181-15-933" and semester_results.course_id not in (
		SELECT 
			semester_results.course_id
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
			semester_results.custom_course_id
	) -- and semester_results.course_title like "%Lab"
GROUP BY
	semester_results.custom_course_id,
	semester_results.course_id,
	semester_results.course_title
HAVING 
	COUNT(semester_results.course_title) >= 1
ORDER BY
	semester_results.custom_course_id
;
