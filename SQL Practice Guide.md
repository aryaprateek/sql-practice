# SQL Practice Guide

A running record of every practice question, my solution, and the traps to remember. One section per session.

## Quick-reference traps

- **Picture the output first.** Before writing SQL, decide what one row means, which joins you need, and the exact row count. Check the data instead of guessing from memory.
- **Anti-join: test NULL on the join key** from the right table, not on another column like a date.
- **NOT IN vs NOT EXISTS.** If the subquery returns even one NULL, NOT IN returns zero rows and gives no error. Prefer NOT EXISTS.
- **Fan-out.** Joining one parent to two child tables multiplies rows (employees × sales), which inflates SUM and COUNT. Aggregate each child separately first, then join.
- **A WHERE filter on the right table cancels a LEFT JOIN**, because NULL comparisons are never true.
- **Integer division.** COUNT / COUNT gives 0 in Postgres and SQL Server. Multiply by 1.0 *before* dividing.
- **Check your brackets around ROUND.** `ROUND(x, 2)`, with the 2 inside.
- **BETWEEN includes both ends.** Overlapping band edges duplicate rows.
- **Wrapping a column in a function drops its name.** Always add an alias.
- **Reread the last line of the question** for ORDER BY and the exact output column names.

## Question index

35 questions across three sessions. Mark each one as you revise it.

| # | Question | Pattern | Rows | Status |
| --- | --- | --- | --- | --- |
| Q1 | Employees with a valid department | INNER JOIN | 4 |  |
| Q2 | Every employee | LEFT JOIN | 6 |  |
| Q3 | RIGHT JOIN, rewritten as LEFT | Join direction | 6 |  |
| Q4 | Match status | FULL OUTER JOIN | 8 |  |
| Q5 | Departments with no employees | Anti-join, NOT IN trap | 2 |  |
| Q6 | Every department × quarter | CROSS JOIN scaffold | 8 |  |
| Q7 | Employee and manager | Self-join | 6 / 2 |  |
| Q8 | Salary bands and headcount | Non-equi join | 6 / 4 |  |
| Q9 | High earners per department | ON vs WHERE | 4 |  |
| Q10 | Headcount, salary, sales | Fan-out | 4 |  |
| Q11 | Source vs target reconciliation | Anti-join + duplicates | — |  |
| Q12 | Full employee view | Multi-join + CTE | 6 |  |
| P1 | Each sale with its department's employees | Join choice | 8 |  |
| P2 | Every department with its employees | LEFT JOIN | 6 |  |
| P3 | Manager's department | Self-join + chain | 6 |  |
| P4 | Filtered counts, HR excluded | ON vs WHERE | 3 |  |
| P5 | Earning more than manager | Self-join filter | 0 |  |
| P6 | Direct-report counts | Self-join + COUNT | 6 |  |
| S1.1 | Missing or invalid department | Anti-join | 2 |  |
| S1.2 | Departments with no sales | NOT EXISTS | 2 |  |
| S1.3 | Pairs in the same department | Self-join, a > b | 2 |  |
| S1.4 | Headcount and sales | Fan-out fix | 4 |  |
| S1.5 | Nobody dropped | Three LEFT JOINs | 6 |  |
| DL1 | Page With No Likes | Anti-join | — |  |
| DL2 | Well Paid Employees | Self-join | — |  |
| DL3 | Signup Activation Rate | Rate, integer division | — |  |
| W1 | Number employees by salary | ROW\_NUMBER, PARTITION BY | 6 |  |
| W2 | ROW\_NUMBER vs RANK vs DENSE\_RANK | Ranking ties | 6 |  |
| W3 | Top earner per department | Top-N per group | 5 |  |
| W4 | Second-highest salary | DENSE\_RANK filter | 1 |  |
| W5 | Every department with its second salary | Rank filter in ON | 4 |  |
| W6 | Quarter-over-quarter change | Aggregate, then LAG | 3 |  |
| W7 | Running total per department | SUM OVER | 3 |  |
| W8 | ROWS vs RANGE on ties | Window frames | 4 |  |
| W9 | Rolling average, full windows only | ROWS frame + CASE | 3 |  |

## Session 0 · 22–24 Oct 2026 · 12-question joins drill

Database: JoinsPractice. Clean reference solutions, with common pitfalls noted underneath.

Key data: Divya has dept\_id NULL; Arjun has dept\_id 50 (doesn't exist); Asha has no manager; Marketing (30) and HR (40) have no employees.

### Level 1 · Q1. INNER JOIN: employees with a valid department (4 rows)

```sql
SELECT e.emp_name, d.dept_name
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id;
```

**Notes:** Divya drops because NULL = anything is never true, not even NULL = NULL. Arjun drops because 50 is an orphan key. INNER also drops Marketing and HR from the other side.

### Level 1 · Q2. LEFT JOIN: every employee (6 rows)

```sql
SELECT e.emp_name, e.dept_id, d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id;
```

**Note:** Divya and Arjun both get a NULL dept\_name for different reasons: missing value vs broken key. Selecting e.dept\_id shows the difference.

### Level 2 · Q3. RIGHT JOIN, then rewrite as LEFT (6 rows)

Every department with its employees, empty departments included.

```sql
SELECT d.dept_name, e.emp_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id;

SELECT d.dept_name, e.emp_name
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id;
```

**Common pitfall:** Writing `FROM departments RIGHT JOIN employees`, which preserves employees. It still gave 6 rows, so the row count alone didn't catch it. Check *which* rows come back. Watch for typos like `employee` instead of `employees`.

**Interview line:** RIGHT JOIN is a LEFT JOIN with the tables flipped. Prefer LEFT for readability.

### Level 2 · Q4. FULL OUTER JOIN with match\_status (8 rows)

```sql
SELECT e.emp_name, d.dept_name,
       CASE WHEN e.emp_id IS NULL THEN 'Dept without employee'
            WHEN d.dept_id IS NULL THEN 'Employee without dept'
            ELSE 'Matched' END AS match_status
FROM employees e
FULL OUTER JOIN departments d ON e.dept_id = d.dept_id;
```

**Note:** Test the primary key of each side, not e.dept\_id, because Divya's dept\_id is NULL before the join even happens.

### Level 3 · Q5. Departments with no employees (Marketing, HR)

```sql
SELECT d.dept_name
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM employees e WHERE e.dept_id = d.dept_id);

SELECT d.dept_name
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL;
```

**The trap:** `WHERE dept_id NOT IN (SELECT dept_id FROM employees)` returns **zero rows**, because Divya's NULL makes every comparison UNKNOWN.

### Level 3 · Q6. CROSS JOIN scaffold: every department × quarter (8 rows, total 14000)

```sql
SELECT d.dept_name, q.quarter, COALESCE(SUM(s.amount), 0) AS total_sales
FROM departments d
CROSS JOIN quarters q
LEFT JOIN sales s ON s.dept_id = d.dept_id AND s.quarter = q.quarter
GROUP BY d.dept_name, q.quarter;
```

**Note:** A plain join can't create combinations that never happened. Build every combination with CROSS JOIN, then LEFT JOIN the facts. Same pattern for date spines and product × region grids. Moving `s.quarter = q.quarter` into WHERE breaks it.

### Level 4 · Q7. Self-join: employee and manager (6 rows)

```sql
SELECT e.emp_name, COALESCE(m.emp_name, 'No manager') AS manager_name
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;

-- Part 2: department differs from manager's (Meena, Arjun)
SELECT e.emp_name
FROM employees e
JOIN employees m ON e.manager_id = m.emp_id
WHERE e.dept_id <> m.dept_id;
```

**Common pitfalls:** Writing `e1.emp_id = e2.manager_id`, which lists direct reports, not managers (9 rows). Read it as a sentence: *e's manager\_id is m's emp\_id*. Use aliases `e` and `m`. Part 2 returns 2 rows, not the 4 you might guess. Divya drops because NULL <> 10 is UNKNOWN, not true.

### Level 4 · Q8. Non-equi join: salary bands

```sql
SELECT e.emp_name, e.salary, sb.band_name
FROM employees e
LEFT JOIN salary_bands sb ON e.salary BETWEEN sb.min_salary AND sb.max_salary;

-- Headcount per band, empty bands included: C 2, B 3, A 1, D 0
SELECT sb.band_name, COUNT(e.emp_id) AS headcount
FROM salary_bands sb
LEFT JOIN employees e ON e.salary BETWEEN sb.min_salary AND sb.max_salary
GROUP BY sb.band_name, sb.min_salary
ORDER BY sb.min_salary;
```

**Notes:** Divya's 70000 sits on a boundary; BETWEEN is inclusive, so she's band B. `COUNT(*)` would show D as 1; count the primary key. FULL JOIN also works here, but only by luck. The question preserves bands only, so LEFT from salary\_bands is precise. Don't forget the ORDER BY.

### Level 5 · Q9. ON vs WHERE: employees earning over 70000 per department

```sql
-- Correct: 4 rows, Marketing and HR show 0
SELECT d.dept_name, COUNT(e.emp_id) AS cnt
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id AND e.salary > 70000
GROUP BY d.dept_name;
```

**Notes:** With the filter in WHERE you get only 2 rows. The LEFT JOIN runs first, then `NULL > 70000` removes the empty departments, turning it into an inner join. Rule: filter on the right table goes in ON; filter on the left table goes in WHERE. My empty result came from typing 700000; sanity-check literals first.

### Level 5 · Q10. Fan-out: headcount, total salary, total sales

The naive three-way join gave Analytics 6 / 600000 / 20000 instead of 2 / 200000 / 10000.

```sql
WITH emp AS (
    SELECT dept_id, COUNT(emp_id) AS headcount, SUM(salary) AS total_salary
    FROM employees GROUP BY dept_id
),
sal AS (
    SELECT dept_id, SUM(amount) AS total_sales
    FROM sales GROUP BY dept_id
)
SELECT d.dept_name,
       COALESCE(emp.headcount, 0) AS headcount,
       COALESCE(emp.total_salary, 0) AS total_salary,
       COALESCE(sal.total_sales, 0) AS total_sales
FROM departments d
LEFT JOIN emp ON emp.dept_id = d.dept_id
LEFT JOIN sal ON sal.dept_id = d.dept_id;
```

**Note:** Two employees × three sales = six rows, so every sum is inflated. Pre-aggregate each child table, then join.

### Level 6 · Q11. Reconciliation: clean source vs target with duplicates

Find source rows missing from the target, target rows not in the source, and duplicated target rows. (Table names here are placeholders.)

```sql
-- Missing in target
SELECT s.* FROM src_txn s
WHERE NOT EXISTS (SELECT 1 FROM tgt_txn t WHERE t.txn_id = s.txn_id);

-- Extra in target
SELECT t.* FROM tgt_txn t
WHERE NOT EXISTS (SELECT 1 FROM src_txn s WHERE s.txn_id = t.txn_id);

-- Duplicated in target
SELECT txn_id, COUNT(*) AS copies
FROM tgt_txn GROUP BY txn_id HAVING COUNT(*) > 1;
```

**Note:** Never compare totals by joining source to target directly: target duplicates fan out. De-duplicate or count in a CTE first, then compare. Practise writing it solo within 15 minutes.

### Level 6 · Q12. Full employee view with above\_dept\_avg

Employee, department, manager, band, and whether salary beats the department average.

```sql
WITH dept_avg AS (
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees GROUP BY dept_id
)
SELECT e.emp_name,
       COALESCE(d.dept_name, 'No department') AS dept_name,
       COALESCE(m.emp_name, 'No manager') AS manager_name,
       sb.band_name,
       CASE WHEN da.avg_salary IS NULL THEN 'N/A'
            WHEN e.salary > da.avg_salary THEN 'Yes'
            ELSE 'No' END AS above_dept_avg
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
LEFT JOIN employees m ON e.manager_id = m.emp_id
LEFT JOIN salary_bands sb ON e.salary BETWEEN sb.min_salary AND sb.max_salary
LEFT JOIN dept_avg da ON e.dept_id = da.dept_id;
```

**Notes:** Divya: her NULL dept\_id can't join to the average, so the comparison is NULL. Handle it explicitly. Arjun: he's alone in dept 50, so he equals his own average and comes out 'No', even though dept 50 isn't real. Build it one CTE at a time; practise it solo within 15 minutes.

## Session 0b · 24 Oct 2026 · Picture-first set (6 questions)

Rule for this set: before any SQL, state what one row means, which joins (and type), and the exact row count.

**The 5-step routine:** 1) define one output row, 2) list tables and how they relate (one-to-many?), 3) decide which rows must survive, 4) build in CTE layers and run each one, 5) verify against source totals.

Sales data: 101 (dept 10, Q1, 5000), 102 (10, Q1, 3000), 103 (20, Q2, 4000), 104 (10, Q2, 2000).

### P1. Each sale with every employee in its department (8 rows)

One row = one sale paired with one employee of that department.

```sql
SELECT s.sale_id, s.amount, d.dept_name, e.emp_name
FROM sales s
LEFT JOIN departments d ON s.dept_id = d.dept_id
LEFT JOIN employees e ON s.dept_id = e.dept_id;
```

**Notes:** Three Analytics sales × 2 employees = 6, plus one Finance sale × 2 = 2. INNER and LEFT give the same 8 here only because the data has no edge cases. Choose the join from the question's wording ("for each sale" means every sale survives), not from matching output. If a sale 105 had dept 50, LEFT gives 9 rows with a NULL dept\_name (dept\_id stays 50), and Arjun (also dept 50) would still pair with it through the employees join.

### P2. Every department with its employees (6 rows)

```sql
SELECT d.dept_name, e.emp_name
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id;
```

**Notes:** 4 matched rows plus Marketing and HR with NULL. INNER would give 4. Divya and Arjun correctly don't appear, because the question is about departments. Right first time with the routine.

### P3. Employee, manager, and the manager's department (6 rows)

```sql
SELECT e.emp_name,
       COALESCE(m.emp_name, 'No manager') AS manager_name,
       md.dept_name AS manager_dept
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id
LEFT JOIN departments md ON m.dept_id = md.dept_id;
```

**Note:** The trap is joining departments on the *manager's* dept\_id, not the employee's. Divya has no department but her manager Asha does, so she gets Analytics.

### P4. Filtered department/salary query: ON vs WHERE (reconstructed)

Every department except HR, with the count of employees earning over 70000 (3 rows).

```sql
SELECT d.dept_name, COUNT(e.emp_id) AS high_earners
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id AND e.salary > 70000
WHERE d.dept_name <> 'HR'
GROUP BY d.dept_name;
```

**Notes:** Right-table filter goes in ON, left-table filter in WHERE. A quoted-string syntax slip can silently return an empty set. Don't switch a correct LEFT JOIN to INNER just because the output matches on this data.

### P5. Employees earning more than their manager (0 rows)

```sql
SELECT e.emp_name, e.salary, m.emp_name AS manager_name, m.salary AS manager_salary
FROM employees e
JOIN employees m ON e.manager_id = m.emp_id
WHERE e.salary > m.salary;
```

**Note:** In this dataset nobody out-earns their manager, so an empty result is correct. Predict it, so you don't assume a bug. INNER is right here: someone with no manager can't out-earn one.

### P6. Direct-report count per employee, zeros included (6 rows)

```sql
SELECT e.emp_name, COUNT(r.emp_id) AS direct_reports
FROM employees e
LEFT JOIN employees r ON r.manager_id = e.emp_id
GROUP BY e.emp_id, e.emp_name;
```

**Notes:** Asha 3, Meena 2, everyone else 0. LEFT keeps people with no reports; COUNT(r.emp\_id) gives them 0, while COUNT(\*) would wrongly give 1. Group by both emp\_id and emp\_name. Self-join type rule: LEFT when every employee must appear, INNER when the relationship itself is required.

## Session 1 · Mon 26 Oct 2026 · Joins

Database: JoinsPractice (employees, departments, sales, salary\_bands).

### Q1. Anti-join: employees with a missing or invalid department

List employees whose department doesn't exist in `departments`, including anyone with no department. Expected 2 rows (Divya, Arjun).

```sql
SELECT e.emp_name, e.dept_id
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;
```

**Note:** Filter on `d.dept_id` (the right table), not `e.dept_id`. That catches both the NULL department (Divya) and the non-existent department 50 (Arjun).

### Q2. Anti-join, other direction: departments with no sales

Expected 2 rows (Marketing, HR).

```sql
-- LEFT JOIN version
SELECT d.dept_id, d.dept_name
FROM departments d
LEFT JOIN sales s ON d.dept_id = s.dept_id
WHERE s.dept_id IS NULL;

-- NOT EXISTS version
SELECT d.dept_id, d.dept_name
FROM departments d
WHERE NOT EXISTS (SELECT 1 FROM sales s WHERE s.dept_id = d.dept_id);
```

**Notes:**

- Don't select right-table columns (like `s.sale_id`) in an anti-join; they're always NULL.
- **NOT IN trap:** `WHERE dept_id NOT IN (SELECT dept_id FROM sales)` returns nothing if any sales row has a NULL dept\_id. Use NOT EXISTS.

### Q3. Self-join: pairs of employees in the same department, each pair once

Expected 2 rows (Ravi–Asha, Karan–Meena).

```sql
SELECT e1.emp_name, e2.emp_name
FROM employees e1
JOIN employees e2
  ON e1.dept_id = e2.dept_id
 AND e1.emp_id > e2.emp_id;
```

**Notes:**

- Joining on equality alone gives self-matches (Ravi–Ravi) and both orders. Adding `<` or `>` on the ID removes both.
- Predict from the actual dept\_id column, not from memory.

**Bonus: pairs who share a manager** (4 rows)

```sql
SELECT e1.emp_name, e2.emp_name
FROM employees e1
JOIN employees e2
  ON e1.manager_id = e2.manager_id
 AND e1.emp_id < e2.emp_id;
```

Asha doesn't appear because her manager\_id is NULL, and NULL never equals anything.

### Q4. Fan-out trap: headcount and total sales per department

One row per department (4 rows), with zeros where there's no data.

**Wrong (naive) version:** Analytics showed headcount 6 and sales 20,000 (real: 2 and 10,000). Finance was doubled too.

```sql
SELECT d.dept_name, COUNT(e.emp_id) AS headcount, SUM(s.amount) AS total_sales
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN sales s ON d.dept_id = s.dept_id
GROUP BY d.dept_name;
```

**Fixed version:**

```sql
WITH count_emp AS (
    SELECT dept_id, COUNT(emp_id) AS headcount
    FROM employees
    GROUP BY dept_id
),
totalsales AS (
    SELECT dept_id, SUM(amount) AS total_sales
    FROM sales
    GROUP BY dept_id
)
SELECT d.dept_name,
       COALESCE(ce.headcount, 0) AS headcount,
       COALESCE(ts.total_sales, 0) AS total_sales
FROM departments d
LEFT JOIN count_emp ce ON d.dept_id = ce.dept_id
LEFT JOIN totalsales ts ON d.dept_id = ts.dept_id;
```

**Notes:**

- With 2 employees and 3 sales, each sale is counted twice and each employee three times.
- Fix: pre-aggregate each child table to one row per department, then join.
- COALESCE turns NULL into 0, and it needs an alias or the column loses its name.

### Q5. Multi-join, nobody dropped

All 6 employees with department name, manager name and salary band.

```sql
SELECT e.emp_name,
       COALESCE(d.dept_name, 'No department') AS dept_name,
       COALESCE(m.emp_name, 'No Manager') AS manager_name,
       sb.band_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
LEFT JOIN employees m ON e.manager_id = m.emp_id
LEFT JOIN salary_bands sb ON e.salary BETWEEN sb.min_salary AND sb.max_salary;
```

**Notes:**

- An inner join would drop 3 people: Divya and Arjun at the department join, and Asha at the manager join.
- Range join: BETWEEN includes both ends, so if band edges overlap, one employee matches two bands and the row is duplicated (hidden fan-out).
- Don't add `e.emp_id > m.emp_id` to an employee–manager join. It silently drops people.

### DataLemur 1. Page With No Likes (Facebook, Easy) · \~4 min

```sql
SELECT p.page_id
FROM pages AS p
LEFT JOIN page_likes AS pl ON p.page_id = pl.page_id
WHERE pl.page_id IS NULL
ORDER BY p.page_id;
```

**Notes:**

- Filtering `pl.liked_date IS NULL` passes, but test NULL on the join key: a page appears in page\_likes only if it was liked, so `pl.page_id` is NULL only when there was no match.
- The question asks for ascending order. Without ORDER BY, the order isn't guaranteed.
- Check table names in the schema before typing (page\_likes, not pages\_likes).

### DataLemur 2. Well Paid Employees (FAANG, Easy) · \~3 min

Employees who earn more than their manager.

```sql
SELECT e.employee_id, e.name AS employee_name
FROM employee AS e
JOIN employee AS m ON e.manager_id = m.employee_id
WHERE e.salary > m.salary;
```

**Notes:**

- A LEFT JOIN here is misleading: `WHERE e.salary > m.salary` drops rows with no manager anyway, so it acts as an inner join. Write JOIN to show what you mean. This is a classic interview follow-up.
- Match the expected column name (employee\_name).
- Basic join syntax is the same in MySQL, SQL Server and Postgres.

### DataLemur 3. Signup Activation Rate (TikTok, Medium) · \~11 min

Share of signups that confirmed, rounded to 2 decimals. Answer: 0.33.

```sql
WITH distinct_email AS (
  SELECT DISTINCT email_id
  FROM texts
  WHERE signup_action = 'Confirmed'
)
SELECT ROUND((COUNT(de.email_id) * 1.0) / COUNT(e.email_id), 2) AS activation_rate
FROM emails AS e
LEFT JOIN distinct_email AS de ON e.email_id = de.email_id;
```

**Notes:**

- **Inner join bug:** it keeps only confirmed emails, so numerator = denominator. LEFT JOIN keeps every signup in the denominator.
- **Fan-out risk:** one email can have several texts. DISTINCT in the CTE stops double counting.
- **Integer division:** multiply by 1.0 *before* dividing (doing `* 0.1` afterwards gives the wrong answer).
- **Bracket bug:** `ROUND(x), 2` returned "(0,2)". The 2 must sit inside ROUND.
- The example said confirm\_rate but the grader wanted activation\_rate. Match the grader's name.

## Session 2 · Tue 27 Oct 2026 · Window functions I

Test data: Ravi set to 75000 (ties Meena), later Karan set to 75000 (ties Meena in Finance). Reset with the setup script afterwards.

**Core rules:** a window function never removes rows, it only adds a column. NULL in PARTITION BY becomes its own group. ORDER BY inside OVER is ascending by default. You can't use a window function in WHERE, so rank in a CTE and filter outside.

### W1. Number employees by salary within each department (6 rows)

```sql
SELECT emp_name, dept_id, salary,
       ROW_NUMBER() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
FROM employees
ORDER BY dept_id, salary_rank;
```

**Common pitfalls:** It's easy to expect 4 rows, assuming NULL departments drop out. All 6 return; Divya (NULL) and Arjun (50) each get 1. Without DESC, the lowest earner is ranked first. Show dept\_id and salary so the result can be checked at a glance.

### W2. ROW\_NUMBER vs RANK vs DENSE\_RANK with a tie (company-wide)

> **Setup note:** this question needs Ravi tied with Meena at 75,000. Run this first and keep it in place through W5.

```sql
UPDATE employees SET salary = 75000 WHERE emp_name = 'Ravi';
```

```sql
SELECT emp_name, salary,
       ROW_NUMBER() OVER (ORDER BY salary DESC, emp_id) AS row_num,
       RANK()       OVER (ORDER BY salary DESC) AS rnk,
       DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_rnk
FROM employees;
```

| Employee | Salary | ROW\_NUMBER | RANK | DENSE\_RANK |
| --- | --- | --- | --- | --- |
| Asha | 120000 | 1 | 1 | 1 |
| Ravi | 75000 | 2 | 2 | 2 |
| Meena | 75000 | 3 | 2 | 2 |
| Divya | 70000 | 4 | 4 | 3 |
| Karan | 60000 | 5 | 5 | 4 |
| Arjun | 55000 | 6 | 6 | 5 |

**Notes:** RANK skips after a tie; DENSE\_RANK doesn't (dense = no gaps). With no partition, it's one company-wide list. ROW\_NUMBER breaks ties arbitrarily, so add a tiebreaker (emp\_id) for repeatable results.

### W3. Top earner per department, keeping ties

> **Setup note:** this question needs a tie. Run this first so Karan ties Meena at 75,000 in dept 20; expected result is then 5 rows (Asha, Meena, Karan, Arjun, Divya).

```sql
UPDATE employees SET salary = 75000 WHERE emp_name = 'Karan';
```

Keep both Ravi and Karan at 75,000 through W4 and W5 (W4 then returns 1 row: Ravi). After W5, reset by re-running 00\_setup\_joinspractice.sql.

```sql
WITH ranked AS (
    SELECT emp_id, emp_name, dept_id, salary,
           RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
    FROM employees
)
SELECT emp_id, emp_name, dept_id, salary
FROM ranked
WHERE salary_rank = 1
ORDER BY dept_id;
```

**Notes:** First decide whether ties are allowed. Exactly one per group: ROW\_NUMBER. Keep ties: RANK or DENSE\_RANK (same result for top 1). For top 2 with a tie at first, RANK gives 2 people, DENSE\_RANK gives 3. Don't join back to employees; the CTE already has the columns. With Karan tied, Finance returns Meena and Karan.

### W4. Second-highest salary per department (1 row: Ravi)

```sql
WITH ranked AS (
    SELECT emp_id, emp_name, dept_id, salary,
           DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
    FROM employees
)
SELECT emp_id, emp_name, dept_id, salary
FROM ranked
WHERE salary_rank = 2;
```

**Note:** Finance returns nothing because its only two people are tied at 1. DENSE\_RANK is usually what "second-highest salary" means; RANK can skip 2 entirely.

### W5. Every department, NULL where there's no second-highest (4 rows)

```sql
WITH ranked AS (
    SELECT emp_name, dept_id, salary,
           DENSE_RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
    FROM employees
)
SELECT d.dept_id, d.dept_name,
       COALESCE(r.emp_name, 'No second highest') AS second_highest_emp,
       r.salary AS second_highest_salary
FROM departments d
LEFT JOIN ranked r ON d.dept_id = r.dept_id AND r.salary_rank = 2
ORDER BY d.dept_id;
```

**Notes:** Departments are the base; the rank filter goes in ON, not WHERE (same lesson as Q9). Using `rank <> 2` in WHERE does the opposite of what's needed. Show the salary, not the rank, and sort by d.dept\_id; sorting by r.emp\_id puts NULL rows first.

## Session 3 · Day 3 (Wed 28 Oct): window functions II

Database: JoinsPractice, `sales` table (4 rows: dept 10 Q1 5000, dept 10 Q1 3000, dept 10 Q2 2000, dept 20 Q2 4000). Core rule: **LAG compares rows, not periods.** Get to one row per period first, then apply the window function.

### W6. Quarter-over-quarter change per department (3 rows)

One row = one department in one quarter. Dept 10 Q2: previous 8000, change -6000. Other rows NULL.

```sql
WITH ct AS (
    SELECT dept_id, quarter, SUM(amount) AS total_amount
    FROM sales
    GROUP BY dept_id, quarter
)
SELECT dept_id, quarter, total_amount,
       LAG(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter) AS previous_qtr,
       total_amount - LAG(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter) AS change
FROM ct;
```

**Common pitfalls:** Joining sales to employees on dept\_id fans out (4 rows became 8). Running LAG on raw rows compares Q1 with Q1 when a period has two rows, and tie order is arbitrary. Joining the CTE back to sales fans out again (10 rows). Prefer NULL over 0 as the LAG default: no previous quarter is not the same as zero sales.

### W7. Running total per department (3 rows)

Expected: 8000, 10000, 4000. PARTITION BY restarts the total for each department.

```sql
WITH ct AS (
    SELECT dept_id, quarter, SUM(amount) AS total_amount
    FROM sales
    GROUP BY dept_id, quarter
)
SELECT dept_id, quarter, total_amount,
       SUM(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter) AS running_total
FROM ct;
```

**Notes:** ORDER BY inside OVER is what makes it cumulative. Remove it and every row gets its department's grand total (useful for percent of total). Name the column `running_total`, not `previous_qtr`.

### W8. ROWS vs RANGE on tied rows (raw sales, 4 rows)

```sql
SELECT dept_id, quarter, amount,
       SUM(amount) OVER (PARTITION BY dept_id ORDER BY quarter
                         RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS range_total,
       SUM(amount) OVER (PARTITION BY dept_id ORDER BY quarter
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_total
FROM sales;
```

| dept\_id | quarter | RANGE | ROWS |
| --- | --- | --- | --- |
| 10 | Q1 | 8000 | 5000 |
| 10 | Q1 | 8000 | 8000 |
| 10 | Q2 | 10000 | 10000 |
| 20 | Q2 | 4000 | 4000 |

**Notes:** RANGE treats rows with the same ORDER BY value as peers, so tied Q1 rows both see all of Q1. ROWS counts physical rows. The default frame with ORDER BY is RANGE, so ties make a running total jump in steps; use ROWS plus a unique tiebreaker for a true row-by-row total. In SQL Server, RANGE only supports UNBOUNDED and CURRENT ROW; offsets like `1 PRECEDING` need ROWS. Common pitfall: forgetting the running total doesn't restart at a new quarter, only at a new partition.

### W9. Two-quarter rolling average, full windows only (3 rows)

Plain rolling average: 8000, 5000, 4000. Full windows only: NULL, 5000, NULL.

```sql
WITH ct_avg AS (
    SELECT dept_id, quarter, SUM(amount) AS total_amount
    FROM sales
    GROUP BY dept_id, quarter
)
SELECT dept_id, quarter, total_amount,
       CASE
         WHEN COUNT(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter
              ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) < 2
         THEN NULL
         ELSE AVG(total_amount) OVER (PARTITION BY dept_id ORDER BY quarter
              ROWS BETWEEN 1 PRECEDING AND CURRENT ROW)
       END AS rolling_avg
FROM ct_avg;
```

**Notes:** The first row of a rolling window averages over itself only, unlike LAG which returns NULL. Window functions can't be nested, so COUNT and AVG sit side by side inside a CASE. Wrap AVG in ROUND or CAST to tidy the decimals. Red IntelliSense markers on CTE columns are a stale cache (Ctrl+Shift+R), not real errors.

## Case questions · Tue 27 Oct 2026

The common trap: jumping straight to causes. Same fix as SQL: picture the structure before answering.

**Framework for "a metric moved, why?" cases**

1. **Is it real?** Tracking or definition changes, missing or late data, duplicates, wrong time window, calendar effects (last period had a sale or holiday).
2. **What is it made of?** Write the metric as a formula or a chain of stages.
3. **Which part moved?** Compare each part with the last period, then slice that part by country, device, platform, plan or tenure.
4. **Only then, causes**, and finish with what you'd do and the impact.

### Case 1. E-commerce revenue down 15% week over week

- **Formula:** revenue = orders × average order value; orders = visitors × conversion rate.
- **Scenario:** visitors and AOV flat, conversion 3% → 2.5%.
- **Next:** walk the funnel: product page → add to cart → checkout → payment. Drop was checkout → payment, Android only.
- **Answer:** a platform-specific drop points to a technical change: a new app release or a payment-provider failure. Slice by app version and payment method; raise it with engineering with the revenue at risk.
- **Common pitfalls:** Slicing by week and department before decomposing; looking at quantity sold, which is a symptom of conversion, not a cause.

### Case 2. Food delivery time up from 30 to 38 minutes

- **Stages:** order accepted → food prepared → rider assigned → pickup → travel → handover.
- **Scenario:** all stages flat except rider assignment, 3 → 10 minutes.
- **Answer:** it's a ratio, so check both sides. Supply: fewer active riders. Demand: an order surge (promotion, new city). Look at orders per available rider by hour and city.
- **Common pitfalls:** Opening with causes (packing, rain, traffic); naming only the supply side of a ratio.

### Case 3. Streaming app monthly active users down from 10M to 9.2M

- **Formula:** this month's MAU = retained users + new users + returning users.
- **Scenario:** new users flat at 1M, returning flat, so retention dropped (churn rose).
- **Next:** slice churned users by country, device, plan, and new vs long-time subscribers; split voluntary cancellations from failed payments (silent churn).
- **Common pitfalls:** Opening with causes (an app update, a rival's new series); saying "check the formula" without writing it; concluding "moved to a rival app" before slicing.

### Case 4. Payments app: successful UPI transactions down 12% week on week

- **Is it real?** Check the definition of "successful" is the same in both weeks, there's no logging or pipeline change, and the data is complete. Check whether last week was inflated (cashback offer, festival, salary day) and compare with the same week last month or last year.
- **What is it made of?** Successful transactions = active users × attempts per user × success rate. Ask how the interviewer defines "successful", but propose the breakdown yourself. A valid breakdown multiplies back to the metric exactly and fits the business (no cart in a payments app).
- **Which part moved?** Compute all three for both weeks before guessing causes. Retries after failures inflate attempts per user, so a success-rate problem can look like an attempts problem. Scenario: success rate fell 95% → 84%.
- **Slice:** all transactions are UPI, so slicing by payment method splits nothing. Use failure reason code first (technical timeouts vs business declines like wrong PIN or insufficient funds), then payer's bank, platform or app version, and time of day.
- **Conclusion and recommendation:** timeouts concentrated at one payer's bank. You can't reroute around the customer's own bank; rerouting only helps if the fault is at the app's partner (PSP) bank. Escalate to the bank and NPCI, show an in-app banner, prompt users to pay from another linked account, track success rate daily, and quantify the lost transactions per day.
- **Common trap:** jumping to causes (gateway, wrong PIN) before establishing which component moved.

**Other case types to practise:** measuring whether a new feature worked; designing an A/B test.
