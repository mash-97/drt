-- select all students from results avg

select
  s.student_id,
  s.student_name,
  s.campus_name,
  round(sum(sr.total_credit), 2) as total_credit_completed,
  round(avg(sr.point_equivalent), 2) as avg_cgpa

from
  students as s,
  semester_results as sr

where
  s.student_id = sr.student_id and 
  sr.point_equivalent not null and
  sr.point_equivalent > 0.5

group by
  s.student_id,
  s.student_name,
  s.campus_name

order by
  total_credit_completed desc, avg_cgpa desc, s.student_id asc;
