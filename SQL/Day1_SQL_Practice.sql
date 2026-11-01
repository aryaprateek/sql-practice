SELECT s.sale_id, s.amount, d.dept_name, e.emp_name FROM sales s
JOIN departments d ON s.dept_id = d.dept_id
LEFT JOIN employees e ON d.dept_id = e.dept_id

SELECT d.dept_id, d.dept_name, e.emp_name
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id

SELECT e.emp_name, m.emp_name AS manager_name, d.dept_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id
LEFT JOIN departments d ON m.dept_id = d.dept_id

SELECT d.dept_name, e.emp_name
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id AND e.salary > 78000
WHERE d.dept_name in ('Analytics', 'Finance')

SELECT e.emp_name, e.salary, m.emp_name, m.salary
FROM employees e
JOIN employees m ON e.manager_id = m.emp_id
WHERE e.salary > m.salary

SELECT m.emp_name AS manager_name, COUNT(e.emp_id) AS no_of_reportees
FROM employees m
LEFT JOIN employees e ON m.emp_id = e.manager_id
GROUP BY m.emp_name


SELECT d.dept_id, d.dept_name, s.sale_id
FROM departments d
LEFT JOIN sales s ON d.dept_id = s.dept_id
WHERE s.dept_id IS NULL

SELECT d.dept_id, d.dept_name
FROM departments d 
WHERE NOT EXISTS (SELECT 1 FROM sales s WHERE s.dept_id = d.dept_id)

SELECT e1.emp_name, e1.dept_id, e2.emp_name, e2.dept_id
FROM employees e1
JOIN employees e2 ON e1.manager_id = e2.manager_id AND e1.emp_id < e2.emp_id;


WITH count_emp AS(
	SELECT dept_id, COUNT(emp_id) AS headcount
	FROM employees
	GROUP BY dept_id
),
totalsales AS(
	SELECT dept_id, SUM(amount) AS total_sales
	FROM sales
	GROUP BY dept_id
)
SELECT d.dept_name, COALESCE(ce.headcount,0) as headcount, COALESCE(ts.total_sales,0) as total_sales
FROM departments d
LEFT JOIN count_emp ce ON d.dept_id = ce.dept_id
LEFT JOIN totalsales ts ON d.dept_id = ts.dept_id

SELECT e.emp_name, 
COALESCE(d.dept_name, 'No department') AS dept_name, 
COALESCE(m.emp_name, 'No Manager') AS manager_name,
sb.band_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
LEFT JOIN employees m ON e.manager_id = m.emp_id
LEFT JOIN salary_bands sb ON e.salary BETWEEN sb.min_salary AND sb.max_salary 
