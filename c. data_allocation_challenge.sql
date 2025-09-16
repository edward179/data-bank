SET search_path = data_bank;

-- 1. running customer balance column that includes impact of each transaction
SELECT customer_id,
       txn_date,
       txn_type,
       txn_amount,
       SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
		WHEN txn_type = 'withdrawal' THEN -txn_amount
		WHEN txn_type = 'purchase' THEN -txn_amount
		ELSE 0
	   END) OVER(PARTITION BY customer_id ORDER BY txn_date) AS running_balance
FROM customer_transactions
ORDER BY customer_id ASC
LIMIT 10;

-- 2. customer balance at the end of each month
SELECT customer_id,
       EXTRACT(MONTH FROM txn_date) AS month,
       TO_CHAR(txn_date, 'Month') AS month_name,
       SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
		WHEN txn_type = 'withdrawal' THEN -txn_amount
		WHEN txn_type = 'purchase' THEN -txn_amount
		ELSE 0
	   END) AS closing_balance
FROM customer_transactions
GROUP BY customer_id, EXTRACT(MONTH FROM txn_date), TO_CHAR(txn_date, 'Month')
LIMIT 10
;

-- 3. minimum, average and maximum values of the running balance for each customer
WITH running_balance AS
(
	SELECT customer_id,
	       txn_date,
	       txn_type,
	       txn_amount,
	       SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
			WHEN txn_type = 'withdrawal' THEN -txn_amount
			WHEN txn_type = 'purchase' THEN -txn_amount
			ELSE 0
		    END) OVER(PARTITION BY customer_id ORDER BY txn_date) AS running_balance
	FROM customer_transactions
)

SELECT customer_id,
       AVG(running_balance) AS avg_running_balance,
       MIN(running_balance) AS min_running_balance,
       MAX(running_balance) AS max_running_balance
FROM running_balance
GROUP BY customer_id
LIMIT 10;


-- For option 1: data is allocated based off the amount of money at the end of the previous month.
WITH transaction_amt_cte AS
(
	SELECT customer_id,
	       txn_date,
	       EXTRACT(MONTH FROM txn_date) AS txn_month,
	       txn_type,
	       CASE WHEN txn_type = 'deposit' THEN txn_amount 
		    ELSE -txn_amount 
	       END AS net_transaction_amt
	FROM customer_transactions
),

running_customer_balance_cte AS
(
	SELECT customer_id,
	       txn_date,
	       txn_month,
	       net_transaction_amt,
	       SUM(net_transaction_amt) OVER(PARTITION BY customer_id, txn_month ORDER BY txn_date
	       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_customer_balance
	FROM transaction_amt_cte
),

customer_end_month_balance_cte AS
(
	SELECT customer_id,
	       txn_month,
	       MAX(running_customer_balance) AS month_end_balance
	FROM running_customer_balance_cte
	GROUP BY customer_id, txn_month
)

SELECT txn_month,
       SUM(month_end_balance) AS data_required_per_month
FROM customer_end_month_balance_cte
GROUP BY txn_month
ORDER BY data_required_per_month DESC
LIMIT 10;

-- For Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days.
WITH transaction_amt_cte AS
(
	SELECT customer_id,
               EXTRACT(MONTH FROM txn_date) AS txn_month,
               SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount
		        ELSE -txn_amount
		    END) AS net_transaction_amt
	FROM customer_transactions
	GROUP BY customer_id, EXTRACT(MONTH FROM txn_date)
),

running_customer_balance_cte AS
(
	SELECT customer_id,
	       txn_month,
	       net_transaction_amt,
	       SUM(net_transaction_amt) OVER(PARTITION BY customer_id ORDER BY txn_month) AS running_customer_balance
	FROM transaction_amt_cte
),

avg_running_customer_balance AS
(
	SELECT customer_id,
	       AVG(running_customer_balance) AS avg_running_customer_balance
	FROM running_customer_balance_cte
	GROUP BY customer_id
)

SELECT txn_month,
       ROUND(SUM(avg_running_customer_balance), 0) AS data_required_per_month
FROM running_customer_balance_cte r
JOIN avg_running_customer_balance a
ON r.customer_id = a.customer_id
GROUP BY txn_month
ORDER BY data_required_per_month
LIMIT 10;

-- For option 3: data is updated real-time.
WITH transaction_amt_cte AS
(
	SELECT customer_id,
	       txn_date,
               EXTRACT(MONTH FROM txn_date) AS txn_month,
               txn_type,
               txn_amount,
               CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END AS net_transaction_amt
	FROM customer_transactions
),

running_customer_balance_cte AS
(
	SELECT customer_id,
	       txn_month,
               SUM(net_transaction_amt) OVER (PARTITION BY customer_id ORDER BY txn_month) AS running_customer_balance
	FROM transaction_amt_cte
)

SELECT txn_month,
       SUM(running_customer_balance) AS data_required_per_month
FROM running_customer_balance_cte
GROUP BY txn_month
ORDER BY data_required_per_month
LIMIT 10;
