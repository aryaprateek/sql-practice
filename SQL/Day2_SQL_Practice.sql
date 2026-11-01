WITH rankCTE AS(
	SELECT emp_id, emp_name, dept_id, salary, RANK() OVER(PARTITION BY dept_id ORDER BY salary DESC) AS salary_dense_rank
	FROM employees
)
SELECT d.dept_id, d.dept_name, rc.emp_name, rc.salary, COALESCE(CAST(rc.salary_dense_rank AS VARCHAR(10)), 'No second highest') AS salary_dense_rank
FROM departments d
LEFT JOIN rankCTE rc ON d.dept_id = rc.dept_id and rc.salary_dense_rank = 2
ORDER BY d.dept_id


