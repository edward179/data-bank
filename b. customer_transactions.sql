SET search_path = data_bank;

--1. What is the unique count and total amount for each transaction type?
SELECT
    txn_type,
    COUNT(*) AS txn_unique_count,
    SUM(txn_amount) AS total_trans
FROM customer_transactions 
GROUP BY txn_type
ORDER BY txn_type;


-- 2. What is the average total historical deposit counts and amounts for all customers?
WITH deposit_summary AS (
    SELECT
        customer_id,
        COUNT(CASE WHEN txn_type = 'deposit' THEN 1 END) AS deposit_cnt,
        SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount END) AS deposit_amount
    FROM customer_transactions
    GROUP BY customer_id
)

SELECT
    AVG(deposit_cnt) AS avg_deposit_cnt,
    AVG(deposit_amount) AS avg_deposit_amount
FROM deposit_summary
;

-- 3.For each month - how many Data Bank customers make more than 1 deposit 
-- and either one purchase or withdrawal in a single month?
WITH customer_activity AS (
    SELECT
        customer_id,
        EXTRACT(MONTH FROM txn_date) AS month_id,
        TO_CHAR(txn_date, 'Month') AS month_name,
        COUNT(CASE WHEN txn_type = 'deposit' THEN 1 END) AS deposit_count,
        COUNT(CASE WHEN txn_type = 'purchase' THEN 1 END) AS purchase_count,
        COUNT(CASE WHEN txn_type = 'withdrawal' THEN 1 END) AS withdrawal_count
    FROM customer_transactions
    GROUP BY
        customer_id,
        EXTRACT(MONTH FROM txn_date),
        TO_CHAR(txn_date, 'Month')
)

SELECT
    month_id,
    month_name,
    COUNT(DISTINCT customer_id) AS active_customer_count
FROM customer_activity
WHERE deposit_count > 1
    AND (purchase_count > 0 OR withdrawal_count > 0)
GROUP BY month_id, month_name
ORDER BY active_customer_count DESC;


-- 4. What is the closing balance for each customer at the end of the month?
WITH customer_cte AS (
    SELECT
        customer_id,
        EXTRACT(MONTH FROM txn_date) AS month_id,
        TO_CHAR(txn_date, 'Mon') AS month_name,
        SUM(
            CASE 
                WHEN txn_type = 'deposit' THEN txn_amount
                WHEN txn_type = 'withdrawal' THEN -txn_amount
                WHEN txn_type = 'purchase' THEN -txn_amount
                ELSE 0
            END
        ) AS month_balance
    FROM customer_transactions
    GROUP BY customer_id, month_name, month_id
    ORDER BY customer_id DESC
)

SELECT
    customer_id,
    month_name,
    month_balance,
    SUM(month_balance) OVER(PARTITION BY customer_id ORDER BY month_id) AS cumulative_balance
FROM customer_cte
ORDER BY customer_id ASC;


-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
WITH monthly_transaction AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', txn_date) + INTERVAL '1 month' - INTERVAL '1 day' AS end_date,
        SUM(
            CASE 
                WHEN txn_type IN ('withdrawal', 'purchase') THEN -txn_amount
            ELSE txn_amount END 
        ) AS transactions
    FROM customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date) + INTERVAL '1 month' - INTERVAL '1 day'
),

closing_balances AS (
    SELECT
        customer_id,
        end_date,
        COALESCE(SUM(transactions) OVER(PARTITION BY customer_id ORDER BY end_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 0) AS closing_balance
    FROM monthly_transaction
),

pct_increase AS (
    SELECT 
        customer_id,
        end_date,
        closing_balance,
        LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY end_date) AS prev_closing_balance,
            100 * (closing_balance - LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY end_date)) / NULLIF(LAG(closing_balance) OVER (PARTITION BY customer_id ORDER BY end_date), 0) AS pct_increase
    FROM closing_balances
)

SELECT CAST(100.0 * COUNT(DISTINCT customer_id) / (SELECT COUNT(DISTINCT customer_id) FROM customer_transactions) AS FLOAT) AS pct_customers
FROM pct_increase
WHERE pct_increase > 5;
