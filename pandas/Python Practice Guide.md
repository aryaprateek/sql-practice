# Python Practice Guide

Nov 2, 2026 · @Prateek Arya

## How to use this guide

This is the one running guide for Python and Pandas practice. Every session gets added here, the same way the SQL Practice Guide works. Each question shows the prediction first, then the code, then the output and the trap it taught.

**Data.** CSV copies of the JoinsPractice tables, saved in the `pandas` folder of the sql-practice repo: `employees_raw.csv` (the 6 employees plus one duplicate Karan row), `departments.csv`, `sales.csv`, `logins.csv`, `salary_bands.csv` and `quarters.csv`.

**Habit before every question:** say what one output row means, predict the row count, then build one step at a time and check `.shape` after each step, the same as running one CTE at a time.

**Setup cell** (the first cell of every notebook):

```python
import pandas as pd
import numpy as np

emp   = pd.read_csv("employees_raw.csv").drop_duplicates()
emp["dept_id"] = emp["dept_id"].astype("Int64")
dept  = pd.read_csv("departments.csv")
sales = pd.read_csv("sales.csv")
lg    = pd.read_csv("logins.csv", parse_dates=["login_date"])
bands = pd.read_csv("salary_bands.csv")
```

### SQL to Pandas map

| SQL | Pandas |
| --- | --- |
| `SELECT TOP 5 *` | `df.head()` |
| `COUNT(*)` of the table | `df.shape` |
| `DISTINCT` rows | `df.drop_duplicates()` |
| `WHERE` | `df[df["col"] > x]` or `df.query("col > x")` |
| `IS NULL` | `df["col"].isna()` |
| `COALESCE(col, 'x')` | `df["col"].fillna("x")` |
| `GROUP BY` + aggregates | `df.groupby("col").agg(name=("col", "sum"))` |
| `HAVING` | filter the result after `agg()` |
| `INNER / LEFT / RIGHT / FULL JOIN` | `merge(how="inner" / "left" / "right" / "outer")` |
| Anti-join (`LEFT JOIN … IS NULL`) | `merge(how="left", indicator=True)`, keep `_merge == "left_only"` |
| `CROSS JOIN` | `merge(how="cross")` |
| Range join (`ON x BETWEEN a AND b`) | cross join, then `x.between(a, b)` |
| `PIVOT` / `SUM(CASE WHEN …)` | `pivot_table(index, columns, values, aggfunc)` |
| `ROW_NUMBER / RANK / DENSE_RANK` | `groupby().rank(method="first" / "min" / "dense")` |
| `LAG` / `LEAD` | `groupby().shift(1)` / `shift(-1)` |
| Running total | `groupby().cumsum()` |
| `ROWS BETWEEN 1 PRECEDING AND CURRENT ROW` | `rolling(2, min_periods=1)` inside `transform` |
| `CASE WHEN` | `np.where` (two outcomes) / `np.select` (several) |
| `ORDER BY` | `sort_values()` |

## Session 5 · Day 5 (Sun 1 Nov): Pandas I

All 9 questions were correct. The main lesson: Pandas handles NULLs differently from SQL in several quiet ways. Notebook: `day5_pandas_I.ipynb`.

| Q | Question | Expected |
| --- | --- | --- |
| F1 | Employees in dept 10 or 20 | 4 rows |
| F2 | No manager, or salary below 60,000 | 2 rows: Asha, Arjun |
| F3 | Not in dept 10 (SQL `NOT IN` behaviour) | 3 rows |
| G1 | Headcount and average salary per dept | 4 rows with `dropna=False`, 3 without (Divya's NULL group disappears) |
| G2 | Headcount, total and highest salary per dept, headcount ≥ 2 | 2 rows: dept 10 and dept 20 |
| M1 | `emp` INNER JOIN `dept` | 4 rows (Divya, Arjun drop out) |
| M2 | `emp` LEFT JOIN `dept` | 6 rows (Divya, Arjun get a blank `dept_name`) |
| M3 | FULL OUTER JOIN | 8 rows |
| M4 | Departments with no employees (anti-join) | 2 rows: Marketing, HR |

```python
emp = pd.read_csv("employees_raw.csv")      # (7, 5): dept_id and manager_id load as float64
emp = emp.drop_duplicates()                    # (6, 5)
emp["dept_id"] = emp["dept_id"].astype("Int64")
emp["manager_id"] = emp["manager_id"].astype("Int64")
dept = pd.read_csv("departments.csv")

emp[emp["dept_id"].isin([10, 20])]                               # F1: 4 rows
emp[(emp["manager_id"].isna()) | (emp["salary"] < 60000)]       # F2: 2 rows
emp[~emp["dept_id"].isin([10]) & emp["dept_id"].notna()]       # F3: 3 rows

emp.groupby("dept_id", dropna=False).agg(                        # G1: 4 rows
    headcount=("emp_id", "count"),
    avg_salary=("salary", "mean"),
).reset_index()

emp.groupby("dept_id", dropna=False).agg(                        # G2: 2 rows
    headcount=("emp_id", "count"),
    total_salary=("salary", "sum"),
    highest_salary=("salary", "max"),
).reset_index().query("headcount >= 2")

emp.merge(dept, on="dept_id", how="inner", indicator=True)       # M1: 4 rows
emp.merge(dept, on="dept_id", how="left", indicator=True)        # M2: 6 rows
emp.merge(dept, on="dept_id", how="outer", indicator=True)       # M3: 8 rows
m = dept.merge(emp, on="dept_id", how="left", indicator=True)
m[m["_merge"] == "left_only"]                                    # M4: 2 rows
```

**Traps:**

- One missing value turns a whole integer column into float64 (10 shows as 10.0), because `NaN` is a float. `astype("Int64")` gives an integer column that allows `<NA>`, like SQL's `INT NULL`. Left and outer merges do the same: M3 turned `emp_id` and `salary` into floats.
- `groupby` drops the NULL group by default, so Divya vanished from G1. Use `dropna=False` to match SQL.
- On Int64, `NULL == 10` is `<NA>` and the row is dropped, like SQL. `isin` always returns `False` for a NULL, so `~isin([10])` **keeps** Divya, unlike SQL's `NOT IN`. In a NOT filter, add `.notna()` or `.isna()` explicitly.
- Wrap each condition in brackets when combining with `&` or `|`.
- In an OR filter a row needs only one condition. F2 is Asha (no manager) plus Arjun (55,000); Karan's 60,000 is not `< 60000`.
- Outer join rows = matched + left-only + right-only (4 + 2 + 2 = 8), never the two tables added together.
- `duplicated()` flags only the second and later copies; the first copy is kept.
- `.query("headcount >= 2")` and the mask style `result[result["headcount"] >= 2]` do the same job. Know both.

## Session 6 · Day 6 (Mon 2 Nov): Pandas II

All 5 steps were correct; the gaps were in explaining why, not in the code. Big takeaway: Pandas window functions have no `ORDER BY` inside them, so you sort first. Notebook: `day6_pandas_II.ipynb`.

### Step 1. pivot\_table (PIVOT / SUM(CASE WHEN))

```python
pv = sales.pivot_table(index="dept_id", columns="quarter",
                       values="amount", aggfunc="sum", fill_value=0, margins=True)

# All 4 departments, not only those with sales:
sales.pivot_table(index="dept_id", columns="quarter", values="amount",
                  aggfunc="sum", fill_value=0).reindex(dept["dept_id"], fill_value=0)
```

| Q | Answer |
| --- | --- |
| P1. Grid size | 2 rows × 2 columns: depts 10 and 20 |
| P2. Dept 20, Q1 without `fill_value` | NaN: no sales row exists for that pair |
| P3. Do Marketing and HR show? | No. A pivot only sees rows in `sales`; fix with `reindex` |
| P4. All/All cell | 14,000 (Q1 8,000 + Q2 6,000) |

**Trap:** the NaN causes the float, not the other way round. NaN is a float, so one empty cell turns the whole column into 8000.0.

### Step 2. Group-wise rank (ROW\_NUMBER / RANK / DENSE\_RANK)

```python
emp["rnk"] = (emp.groupby("dept_id")["salary"]
                 .rank(method="dense", ascending=False))
emp[emp["rnk"] == 1]          # top earner per dept
```

`method="first"` = ROW\_NUMBER · `"min"` = RANK · `"dense"` = DENSE\_RANK.

| Q | Answer |
| --- | --- |
| R1. Rank per dept | Asha 1, Ravi 2, Meena 1, Karan 2, Arjun 1, Divya NaN |
| R2. Company-wide rank | Meena 3, Divya 4 |
| R3. Top earner per dept | 3 rows: Asha, Meena, Arjun |
| R4. Ravi tied with Asha at 120,000 | first: Asha 1, Ravi 2 · min: 1, 1 · dense: 1, 1 |

**Traps:**

- `rank()` returns floats; add `.astype("Int64")` for whole numbers.
- `groupby` drops NULL keys, so Divya gets no rank. SQL's `PARTITION BY` would put her in her own NULL partition with rank 1.
- `min` and `dense` only differ for the person after a tie (3 vs 2).
- `first` breaks ties by row order, so a shuffled file can change the answer. Sort with a tiebreaker first.
- Arjun is "top of dept 50", which doesn't exist. The rank can't spot dirty data.

### Step 3. shift (LAG / LEAD)

```python
lg = pd.read_csv("logins.csv", parse_dates=["login_date"])
lg = lg.sort_values(["emp_id", "login_date"])                      # the ORDER BY
lg["prev_login"] = lg.groupby("emp_id")["login_date"].shift(1)     # LAG
lg["gap_days"]   = (lg["login_date"] - lg["prev_login"]).dt.days
```

| Q | Answer |
| --- | --- |
| S1. Rows with NaT | 2: each employee's first login (Asha and Ravi, 10-01) |
| S2. Asha's gap\_days | NaN, 1, 1, 2, 1, 3 |
| S3. Rows with gap > 1 | 3: Asha 10-05, Asha 10-09, Ravi 10-04. Each starts a new island |
| S4. Skip sort on shuffled rows | No error, wrong gaps (even negative ones) |

**Traps:** `shift` goes by position, not date, so sort first. `parse_dates` is needed to subtract dates. Date minus date is a Timedelta; `.dt.days` makes it a number. 5 islands = 3 gap rows + 2 first rows, not 3.

### Step 4. cumsum and rolling (running total, moving average)

```python
s = sales.sort_values(["dept_id", "sale_id"])
s["running_total"] = s.groupby("dept_id")["amount"].cumsum()
s["avg_2"] = (s.groupby("dept_id")["amount"]
               .transform(lambda x: x.rolling(2, min_periods=1).mean()))

# Gaps and islands, flag-and-cumsum method:
lg["new_island"] = lg["gap_days"] != 1
lg["island_id"]  = lg.groupby("emp_id")["new_island"].cumsum()
```

| Q | Answer |
| --- | --- |
| C1. running\_total | 5000, 8000, 10000, then 4000 (restarts for dept 20) |
| C2. avg\_2 without `min_periods` | NaN, 4000, 2500, NaN: first sale of each dept is NaN |
| C3. With `min_periods=1` | 5000, 4000, 2500, 4000 |
| C4. island\_id | Asha 1, 1, 1, 2, 2, 3 · Ravi 1, 1, 2 |

**Traps:**

- `rolling(n)` gives NaN until it has n rows. SQL's `ROWS BETWEEN 1 PRECEDING` averages what exists, so add `min_periods=1` to match.
- `transform` keeps every original row, like a window function. `agg` collapses to one row per group, like GROUP BY.
- `NaN != 1` is True, so each employee's first row starts island 1. cumsum counts True as 1.

### Step 5. Loops → np.where / np.select (CASE WHEN)

```python
emp["level"] = np.where(emp["salary"] >= 100000, "Senior", "Other")

conditions = [emp["salary"] >= 100000, emp["salary"] >= 70000]
choices    = ["A", "B"]
emp["grade"] = np.select(conditions, choices, default="C")

# NULL-safe condition on an Int64 column:
np.where(emp["dept_id"].eq(10).fillna(False), "Analytics", "Other")
```

| Q | Answer |
| --- | --- |
| W1. Senior count | 1: Asha |
| W2. grade | A, B, B, C, B, C |
| W3. Conditions swapped | Asha gets B: the first true condition wins |
| W4. `np.where(emp["dept_id"] == 10, …)` | TypeError: `<NA> == 10` is unknown, and `np.where` can't pick a branch |

**Traps:**

- `iterrows` loops are slow; vectorized `np.where` tests the whole column at once.
- List conditions from most specific to least specific, as in `CASE`.
- Decide what an unknown counts as with `.fillna(False)`. On a float column, `NaN == 10` is quietly False, which hides the problem.

## Session 6b · SQL problems re-solved in Pandas

T1 is done and matches the SQL answer row for row. T2 and T3 move to the Saturday 7 Nov revision session.

### T1. Salary band report (range join + DENSE\_RANK)

One row = one employee with their band and rank in it. Expected 6 rows. Shape after each step: left join 6 → cross join 24 → BETWEEN filter 6.

```python
bands = pd.read_csv("salary_bands.csv")                       # (4, 3)

e = emp.merge(dept, on="dept_id", how="left")                 # 6 rows, LEFT JOIN
e["dept_name"] = e["dept_name"].fillna("Unknown")              # COALESCE

x = e.merge(bands, how="cross")                               # 24 rows, CROSS JOIN
x = x[x["salary"].between(x["min_salary"], x["max_salary"])]  # 6 rows, the BETWEEN

x["rank_in_band"] = (x.groupby("band_name")["salary"]
                      .rank(method="dense", ascending=False)
                      .astype(int))

result = (x.sort_values(["band_name", "rank_in_band"])
           [["emp_name", "dept_name", "salary", "band_name", "rank_in_band"]]
           .reset_index(drop=True))
```

| emp\_name | dept\_name | salary | band\_name | rank\_in\_band |
| --- | --- | --- | --- | --- |
| Asha | Analytics | 120000 | A | 1 |
| Ravi | Analytics | 80000 | B | 1 |
| Meena | Finance | 75000 | B | 2 |
| Divya | Unknown | 70000 | B | 3 |
| Karan | Finance | 60000 | C | 1 |
| Arjun | Unknown | 55000 | C | 2 |

**Notes:** `merge` only matches equal keys, so a range join is a cross join followed by a filter. `between` includes both ends, like SQL. The leftover row labels (2, 5, 9, 17…) come from the 24-row cross join; `.reset_index(drop=True)` renumbers them 0–5.

### Still to do (Saturday 7 Nov revision)

- [ ] **T2.** Each department's share of quarterly sales (CROSS JOIN departments × quarters + window share). Expected 8 rows: Q1 Analytics 100.0; Q2 Finance 66.7, Analytics 33.3; the rest 0.0.
- [ ] **T3.** Longest login streak per employee, using flag-and-cumsum. Expected 2 rows: Asha 1–3 Oct (3), Ravi 1–2 Oct (2).

## Traps cheat sheet

Read this before every timed Pandas set. Each line is a mistake that gives no error, just a wrong answer, unless noted.

1. **Sort before `shift`, `cumsum` or `rolling`.** Pandas has no ORDER BY inside the window; it uses the current row order.
2. **`groupby` drops NULL keys.** Use `dropna=False` in aggregates. In `rank`, the NULL row gets NaN instead of its own partition.
3. **One NaN turns an int column into float.** Use `astype("Int64")`, or `fill_value=0` in a pivot.
4. **`~isin()` keeps NULLs**, unlike SQL's `NOT IN`. Add `.notna()` explicitly.
5. **`<NA>` in `np.where` raises a TypeError.** Decide with `.fillna(False)`. On float columns NaN comparisons are quietly False.
6. **`rolling(n)` is NaN until it has n rows.** Add `min_periods=1` to match SQL.
7. **A pivot only sees rows that exist.** Use `reindex` to bring in missing categories.
8. **`rank()` returns floats; `method="first"` breaks ties by row order.** Cast with `astype`, and sort with a tiebreaker.
9. **`merge` only does equality joins.** Range join = cross join + `between`.
10. **Outer join rows = matched + left-only + right-only.** Never the two tables added together.
11. **Wrap each condition in brackets** with `&` and `|`.
12. **`np.select` takes the first true condition.** Order from most to least specific.
13. **Say the reason and the row count, not just the value.** Check `.shape` after every step.
