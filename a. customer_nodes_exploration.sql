-- set the path to run code
-- run by using 
-- export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH" psql -U $(whoami) -d postgres -f query.sql
-- replace the `query.sql` with the right file_name
SET search_path = data_bank;

-- Part A. Customer Nodes Exploration
-- 1. How many nodes are there on the Data Bank System?
SELECT COUNT(DISTINCT node_id) AS total_nodes
FROM customer_nodes;

-- 2. What is the number of nodes per region?
SELECT 
    r.region_name,
    COUNT(c.node_id) AS total_nodes
FROM regions r
INNER JOIN customer_nodes c
ON r.region_id = c.region_id
GROUP BY r.region_name
;

-- 3. How many customers are allocated to each region?
SELECT
    r.region_name,
    COUNT(DISTINCT c.customer_id) AS total_customers
FROM customer_nodes c
INNER JOIN regions r
ON c.region_id = r.region_id
GROUP BY r.region_name;

-- 4. How many days on average are customers reallocated to a different region?
-- remember to check the `start_date` and `end_date` to ensure the format is correct first
SELECT AVG(end_date - start_date) AS avg_number_of_day
FROM customer_nodes
WHERE end_date != '9999-12-31';

-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH day_diff AS (
    SELECT
        c.customer_id,
        r.region_id,
        r.region_name,
        (c.end_date - c.start_date) AS reallocation_days
    FROM customer_nodes c
    INNER JOIN regions r
    ON c.region_id = r.region_id
    WHERE c.end_date != '9999-12-31'
)

SELECT DISTINCT
    region_id,
    region_name,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY reallocation_days) AS median,
    PERCENTILE_CONT(0.8) WITHIN GROUP(ORDER BY reallocation_days) AS perc_80,
    PERCENTILE_CONT(0.95) WITHIN GROUP(ORDER BY reallocation_days) AS perc_95
FROM day_diff
GROUP BY region_id, region_name
ORDER BY region_name;



