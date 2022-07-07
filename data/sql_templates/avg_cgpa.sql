select 
	AVG(semester_results.point_equivalent) 
from 
	semester_results 
where 
	semester_results.student_id like "172-33-3983" and semester_results.point_equivalent >= 0.5;