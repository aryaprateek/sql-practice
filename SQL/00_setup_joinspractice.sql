/* JoinsPractice: full setup script (SQL Server). Safe to re-run. */
IF DB_ID('JoinsPractice') IS NULL
    CREATE DATABASE JoinsPractice;
GO
USE JoinsPractice;
GO

DROP TABLE IF EXISTS dbo.src_txn;
DROP TABLE IF EXISTS dbo.tgt_txn;
DROP TABLE IF EXISTS dbo.salary_bands;
DROP TABLE IF EXISTS dbo.sales;
DROP TABLE IF EXISTS dbo.quarters;
DROP TABLE IF EXISTS dbo.employees;
DROP TABLE IF EXISTS dbo.departments;
GO

/* departments */
CREATE TABLE dbo.departments (
    dept_id   INT         NOT NULL PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL
);
INSERT INTO dbo.departments VALUES
(10, 'Analytics'), (20, 'Finance'), (30, 'Marketing'), (40, 'HR');

/* employees: no foreign key on purpose
   (Divya has NULL dept, Arjun has orphan dept 50) */
CREATE TABLE dbo.employees (
    emp_id     INT           NOT NULL PRIMARY KEY,
    emp_name   VARCHAR(50)   NOT NULL,
    dept_id    INT           NULL,
    manager_id INT           NULL,
    salary     DECIMAL(10,2) NOT NULL
);
INSERT INTO dbo.employees VALUES
(1, 'Asha',  10,   NULL, 120000),
(2, 'Ravi',  10,   1,     80000),
(3, 'Meena', 20,   1,     75000),
(4, 'Karan', 20,   3,     60000),
(5, 'Divya', NULL, 1,     70000),
(6, 'Arjun', 50,   3,     55000);

/* quarters */
CREATE TABLE dbo.quarters (
    quarter VARCHAR(2) NOT NULL PRIMARY KEY
);
INSERT INTO dbo.quarters VALUES ('Q1'), ('Q2');

/* sales */
CREATE TABLE dbo.sales (
    sale_id INT           NOT NULL PRIMARY KEY,
    dept_id INT           NOT NULL,
    quarter VARCHAR(2)    NOT NULL,
    amount  DECIMAL(10,2) NOT NULL
);
INSERT INTO dbo.sales VALUES
(101, 10, 'Q1', 5000),
(102, 10, 'Q1', 3000),
(103, 20, 'Q2', 4000),
(104, 10, 'Q2', 2000);

/* salary_bands: inclusive on both ends */
CREATE TABLE dbo.salary_bands (
    band_name  VARCHAR(10)   NOT NULL PRIMARY KEY,
    min_salary DECIMAL(10,2) NOT NULL,
    max_salary DECIMAL(10,2) NOT NULL
);
INSERT INTO dbo.salary_bands VALUES
('C',  50000,  69999),
('B',  70000,  99999),
('A', 100000, 149999),
('D', 150000, 199999);

/* src_txn: clean source, one row per txn_id */
CREATE TABLE dbo.src_txn (
    txn_id INT           NOT NULL PRIMARY KEY,
    amount DECIMAL(10,2) NOT NULL
);
INSERT INTO dbo.src_txn VALUES
(1, 100), (2, 200), (3, 300), (4, 400), (5, 500);

/* tgt_txn: warehouse, no primary key on purpose (duplicates allowed) */
CREATE TABLE dbo.tgt_txn (
    txn_id INT           NOT NULL,
    amount DECIMAL(10,2) NOT NULL
);
INSERT INTO dbo.tgt_txn VALUES
(1, 100), (2, 250), (3, 300), (3, 300), (6, 600);
GO

/* quick check */
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM dbo.departments
UNION ALL SELECT 'employees',    COUNT(*) FROM dbo.employees
UNION ALL SELECT 'quarters',     COUNT(*) FROM dbo.quarters
UNION ALL SELECT 'sales',        COUNT(*) FROM dbo.sales
UNION ALL SELECT 'salary_bands', COUNT(*) FROM dbo.salary_bands
UNION ALL SELECT 'src_txn',      COUNT(*) FROM dbo.src_txn
UNION ALL SELECT 'tgt_txn',      COUNT(*) FROM dbo.tgt_txn;
-- Expected: 4, 6, 2, 4, 4, 5, 5