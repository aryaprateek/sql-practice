WITH ct AS(
	SELECT dept_id, quarter, SUM(amount) as total_amount
	FROM sales
	GROUP BY dept_id, quarter
)

SELECT
dept_id,
quarter,
total_amount,
LAG(total_amount,1,NULL) OVER (PARTITION BY dept_id ORDER BY quarter) AS previous_qtr,
(total_amount - LAG(total_amount,1,NULL) OVER (PARTITION BY dept_id ORDER BY quarter)) AS 'change'
FROM ct
-----------------------------------------------------------------------------------------------------
WITH ct AS(
	SELECT dept_id, quarter, SUM(amount) as total_amount
	FROM sales
	GROUP BY dept_id, quarter
)
SELECT
dept_id,
quarter,
total_amount,
SUM(total_amount) OVER (PARTITION BY dept_id) AS running_total
FROM ct
-----------------------------------------------------------------------------------------------------
SELECT
dept_id,
quarter,
amount,
SUM(amount) OVER (PARTITION BY dept_id ORDER BY quarter
               RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS 'range',

SUM(amount) OVER (PARTITION BY dept_id ORDER BY quarter
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS 'rows'
FROM sales;

-----------------------------------------------------------------------------------------------------
WITH ct_avg AS(
	SELECT dept_id, quarter, SUM(amount) as total_amount
	FROM sales
	GROUP BY dept_id, quarter
)
SELECT
dept_id,
quarter,
total_amount,
AVG(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS rolling_avg
FROM ct_avg

-----------------------------------------------------------------------------------------------------
WITH ct_avg AS(
	SELECT dept_id, quarter, SUM(amount) as total_amount
	FROM sales
	GROUP BY dept_id, quarter
)
SELECT
dept_id,
quarter,
total_amount,
CASE
  WHEN COUNT(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter
       ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) < 2
  THEN NULL
  ELSE AVG(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter
       ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)
END AS rolling_avg
FROM ct_avg