-- Author: Prateek Arya

--Question 1---------------------------------------------------------------------
WITH emp_salary  AS (
	SELECT e.emp_name, e.dept_id, d.dept_name, e.salary
	FROM employees e
	JOIN departments d ON e.dept_id = d.dept_id
),
Dept_Avg AS (
	SELECT *,
	AVG(salary) OVER (PARTITION BY dept_id) as avg_dept_salary
	FROM emp_salary
)

SELECT *
FROM Dept_Avg
WHERE salary > avg_dept_salary

--Question 2---------------------------------------------------------------------
WITH emp_salary  AS (
	SELECT e.emp_id, e.emp_name, e.dept_id, d.dept_name, e.salary
	FROM employees e
	JOIN departments d ON e.dept_id = d.dept_id
),
Max_sal AS (
	SELECT *,
	MAX(salary) OVER (PARTITION BY dept_id) as max_dept_salary
	FROM emp_salary
)

SELECT dept_name, COUNT(emp_id) AS emp_count
FROM Max_sal
WHERE salary >= (max_dept_salary*0.75)
GROUP BY dept_name;

--Question 3---------------------------------------------------------------------
WITH Dept_sales AS (
	SELECT d.dept_id, d.dept_name, s.sale_id, s.amount
	FROM departments d
	JOIN sales s ON d.dept_id = s.dept_id
),

Avg_sales AS(
	SELECT *,
	AVG(amount) OVER(PARTITION BY dept_id) AS avg_sales
	FROM Dept_sales
)

SELECT dept_name, COUNT(CASE WHEN amount > avg_sales THEN sale_id END) AS count_of_sales,
SUM(CASE WHEN amount > avg_sales THEN amount ELSE 0 END) AS total_sales_amount
FROM Avg_sales
GROUP BY dept_name;


--Question 4---------------------------------------------------------------------
WITH grp_login AS (
	SELECT emp_id, login_date, DATEADD(DAY, - ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY login_date), login_date) AS grp
	FROM logins
)
SELECT
gl.emp_id,
gl.grp,
MIN(gl.login_date) AS start_date,
MAX(gl.login_date) AS end_date,
COUNT(*) AS length_days
FROM grp_login gl
GROUP BY gl.emp_id, gl.grp
ORDER BY gl.emp_id, MIN(gl.login_date)