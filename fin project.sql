CREATE DATABASE customers_transactions;
UPDATE customers SET Gender = NULL WHERE Gender = '';
UPDATE customers SET Age = NULL WHERE Age = '';
ALTER TABLE customers MODIFY Age INT NULL;

select * from customers;

CREATE TABLE transactions
(date_new DATE ,
Id_check INT,
ID_client INT,
Count_products DECIMAL(10,3),
Sum_payment DECIMAL(10,2));

LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\TRANSACTIONS_final.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SHOW VARIABLES LIKE 'secure_file_priv';

select * from transactions;

# Задание 1
# Список клиентов с непрерывной историей за год

WITH monthly_transactions AS (
    SELECT 
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS month_year,
        COUNT(*) AS transaction_count,
        SUM(Sum_payment) AS total_amount
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY ID_client, DATE_FORMAT(date_new, '%Y-%m')
),
continuous_clients AS (
    SELECT 
        ID_client,
        COUNT(DISTINCT month_year) AS months_active
    FROM monthly_transactions
    GROUP BY ID_client
    HAVING months_active = 13
)

SELECT 
    c.Id_client,
    c.Gender,
    c.Age,
    c.Count_city,
    COUNT(t.Id_check) AS total_transactions,
    SUM(t.Sum_payment) AS total_amount,
    SUM(t.Sum_payment) / COUNT(t.Id_check) AS avg_check,
    SUM(t.Sum_payment) / 13 AS avg_monthly_spend
FROM customers c
JOIN transactions t ON c.Id_client = t.ID_client
JOIN continuous_clients cc ON c.Id_client = cc.ID_client
WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
GROUP BY c.Id_client, c.Gender, c.Age, c.Count_city
ORDER BY total_amount DESC;

# Задание 2
# Информация в разрезе месяцев

WITH monthly_stats AS (
    SELECT 
        DATE_FORMAT(date_new, '%Y-%m') AS month_year,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT ID_client) AS unique_clients,
        SUM(Sum_payment) AS total_amount,
        SUM(Sum_payment) / COUNT(*) AS avg_check
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY DATE_FORMAT(date_new, '%Y-%m')
)    
    SELECT 
    month_year,
    avg_check,
    transaction_count,
    unique_clients,
    transaction_count / (SELECT SUM(transaction_count) FROM monthly_stats) * 100 AS pct_of_total_transactions,
    total_amount / (SELECT SUM(total_amount) FROM monthly_stats) * 100 AS pct_of_total_amount
FROM monthly_stats
ORDER BY month_year;

# Гендерное распределение по месяцам

WITH gender_monthly AS (
    SELECT 
        DATE_FORMAT(t.date_new, '%Y-%m') AS month_year,
        COALESCE(c.Gender, 'NA') AS gender,
        COUNT(*) AS transaction_count,
        SUM(t.Sum_payment) AS total_amount
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY DATE_FORMAT(t.date_new, '%Y-%m'), COALESCE(c.Gender, 'NA')
),
monthly_totals AS (
    SELECT 
        month_year,
        SUM(transaction_count) AS total_transactions,
        SUM(total_amount) AS total_amount
    FROM gender_monthly
    GROUP BY month_year
)

SELECT 
    g.month_year,
    g.gender,
    g.transaction_count,
    g.total_amount,
    (g.transaction_count / m.total_transactions) * 100 AS pct_transactions,
    (g.total_amount / m.total_amount) * 100 AS pct_amount
FROM gender_monthly g
JOIN monthly_totals m ON g.month_year = m.month_year
ORDER BY g.month_year, g.gender;

# Задание 3 
# Возрастные группы клиентов

WITH age_groups AS (
    SELECT 
        CASE 
            WHEN Age IS NULL THEN 'NA'
            WHEN Age < 20 THEN '0-19'
            WHEN Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN Age >= 70 THEN '70+'
        END AS age_group,
        t.ID_client,
        COUNT(*) AS transaction_count,
        SUM(t.Sum_payment) AS total_amount,
        QUARTER(t.date_new) AS quarter
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
    WHERE t.date_new BETWEEN '2015-06-01' AND '2016-06-01'
    GROUP BY 
        CASE 
            WHEN Age IS NULL THEN 'NA'
            WHEN Age < 20 THEN '0-19'
            WHEN Age BETWEEN 20 AND 29 THEN '20-29'
            WHEN Age BETWEEN 30 AND 39 THEN '30-39'
            WHEN Age BETWEEN 40 AND 49 THEN '40-49'
            WHEN Age BETWEEN 50 AND 59 THEN '50-59'
            WHEN Age BETWEEN 60 AND 69 THEN '60-69'
            WHEN Age >= 70 THEN '70+'
        END,
        t.ID_client,
        QUARTER(t.date_new)
)

SELECT 
    age_group,
    SUM(total_amount) AS total_amount,
    SUM(transaction_count) AS transaction_count,
    SUM(total_amount) / SUM(transaction_count) AS avg_check,
    SUM(total_amount) / (SELECT SUM(Sum_payment) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') * 100 AS pct_of_total_amount,
    SUM(transaction_count) / (SELECT COUNT(*) FROM transactions WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01') * 100 AS pct_of_total_transactions
FROM age_groups
GROUP BY age_group
ORDER BY 
    CASE 
        WHEN age_group = 'NA' THEN 8
        WHEN age_group = '0-19' THEN 1
        WHEN age_group = '20-29' THEN 2
        WHEN age_group = '30-39' THEN 3
        WHEN age_group = '40-49' THEN 4
        WHEN age_group = '50-59' THEN 5
        WHEN age_group = '60-69' THEN 6
        WHEN age_group = '70+' THEN 7
    END;

SELECT 
    age_group,
    quarter,
    AVG(total_amount) AS avg_quarterly_amount,
    AVG(transaction_count) AS avg_quarterly_transactions,
    SUM(total_amount) / (SELECT SUM(Sum_payment) FROM transactions
                         WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01' 
                         AND QUARTER(date_new) = ag.quarter) * 100 AS pct_of_quarter_amount,
    SUM(transaction_count) / (SELECT COUNT(*) FROM transactions 
                              WHERE date_new BETWEEN '2015-06-01' AND '2016-06-01' 
                              AND QUARTER(date_new) = ag.quarter) * 100 AS pct_of_quarter_transactions
FROM age_groups ag
GROUP BY age_group, quarter
ORDER BY quarter, 
    CASE 
        WHEN age_group = 'NA' THEN 8
        WHEN age_group = '0-19' THEN 1
        WHEN age_group = '20-29' THEN 2
        WHEN age_group = '30-39' THEN 3
        WHEN age_group = '40-49' THEN 4
        WHEN age_group = '50-59' THEN 5
        WHEN age_group = '60-69' THEN 6
        WHEN age_group = '70+' THEN 7
    END; 