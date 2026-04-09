
CREATE DATABASE clique_bait;
USE clique_bait;


CREATE TABLE users 
(	user_id INT,
    cookie_id VARCHAR(50));

INSERT INTO users (user_id, cookie_id) VALUES
(1, 'cookie_001'),
(2, 'cookie_002'),
(3, 'cookie_003'),
(4, 'cookie_004'),
(5, 'cookie_005');

DROP TABLE IF EXISTS events;

CREATE TABLE events 
(	visit_id VARCHAR(50),
    cookie_id VARCHAR(50),
    page_id INT,
    event_type INT,
    sequence_number INT,
    event_time DATETIME);

INSERT INTO events VALUES
('visit_001','cookie_001',1,1,1,'2020-01-01 10:00:00'),
('visit_001','cookie_001',2,1,2,'2020-01-01 10:01:00'),
('visit_001','cookie_001',3,2,3,'2020-01-01 10:02:00'),
('visit_002','cookie_002',1,1,1,'2020-01-02 11:00:00'),
('visit_002','cookie_002',4,3,2,'2020-01-02 11:02:00'),
('visit_003','cookie_003',2,1,1,'2020-01-03 12:00:00');

DROP TABLE IF EXISTS event_identifier;

CREATE TABLE event_identifier 
(	event_type INT,
    event_name VARCHAR(50));

INSERT INTO event_identifier VALUES
(1, 'page_view'),
(2, 'add_to_cart'),
(3, 'purchase'),
(4, 'ad_click'),
(5, 'impression');

DROP TABLE IF EXISTS page_hierarchy;

CREATE TABLE page_hierarchy 
(	page_id INT,
    page_name VARCHAR(100),
    product_category VARCHAR(50),
    product_id INT);
    
INSERT INTO page_hierarchy VALUES
(1, 'Homepage', NULL, NULL),
(2, 'Product Page A', 'Electronics', 101),
(3, 'Cart Page', NULL, NULL),
(4, 'Checkout Page', NULL, NULL),
(5, 'Product Page B', 'Clothing', 102);


Select * FROM users;
Select * FROM events;
Select * FROM event_identifier;
Select * FROM page_hierarchy;

B. Digital Analysis
Using the available datasets - answer the following questions using a single query for each one:

1. How many users are there?

SELECT 
    COUNT(DISTINCT user_id) AS total_users
FROM users;

2. How many cookies does each user have on average?

SELECT 
    ROUND(COUNT(cookie_id) * 1.0 / COUNT(DISTINCT user_id), 2) AS avg_cookies_per_user
FROM users;

3. What is the unique number of visits by all users per month?

SELECT 
    u.user_id,
    YEAR(e.event_time) AS year_num,
    MONTH(e.event_time) AS month_num,
    COUNT(DISTINCT e.visit_id) AS num_visits
	FROM events e JOIN users u ON e.cookie_id = u.cookie_id
	GROUP BY u.user_id, YEAR(e.event_time), MONTH(e.event_time)
	ORDER BY u.user_id, year_num, month_num;

4. What is the number of events for each event type?

SELECT 
    ei.event_name, COUNT(*) AS num_of_events
FROM events e
JOIN event_identifier ei
    ON e.event_type = ei.event_type GROUP BY ei.event_name;

5. What is the percentage of visits which have a purchase event?

SELECT 
    'Purchase' AS event_name,
    ROUND(COUNT(DISTINCT CASE WHEN ei.event_name = 'Purchase' THEN e.visit_id END) * 100.0/ COUNT(DISTINCT e.visit_id),2) AS perc_of_visits
FROM events e
JOIN event_identifier ei
    ON e.event_type = ei.event_type;

6. What is the percentage of visits which view the checkout page but do not have a purchase event?

WITH visit_flags AS 
(SELECT
        e.visit_id,
        MAX(CASE WHEN ph.page_name = 'Checkout Page' THEN 1 ELSE 0 END) AS viewed_checkout,
        MAX(CASE WHEN ei.event_name = 'purchase' THEN 1 ELSE 0 END) AS made_purchase
    FROM events e
    JOIN page_hierarchy ph
        ON e.page_id = ph.page_id JOIN event_identifier ei ON e.event_type = ei.event_type GROUP BY e.visit_id)
SELECT
    ROUND(COUNT(CASE WHEN viewed_checkout = 1 AND made_purchase = 0 THEN 1 END) * 100.0/ COUNT(CASE WHEN viewed_checkout = 1 THEN 1 END),2) AS percentage_checkout_no_purchase
FROM visit_flags;

7. What are the top 3 pages by number of views?

SELECT 
    ph.page_name,
    COUNT(*) AS num_views
FROM events e
JOIN page_hierarchy ph
    ON e.page_id = ph.page_id
JOIN event_identifier ei
    ON e.event_type = ei.event_type
WHERE ei.event_name = 'page_view'
GROUP BY ph.page_name
ORDER BY num_views DESC
LIMIT 3;

8. What is the number of views and cart adds for each product category?

SELECT 
    ph.product_category,
    ei.event_name,
    COUNT(*) AS event_count
FROM events e
JOIN event_identifier ei ON e.event_type = ei.event_type
JOIN page_hierarchy ph ON e.page_id = ph.page_id
WHERE ph.product_category IS NOT NULL AND ei.event_name IN ('page_view', 'add_to_cart')
GROUP BY ph.product_category, ei.event_name
ORDER BY ph.product_category, ei.event_name;

9. What are the top 3 products by purchases?

WITH purchased_visits AS 
(SELECT DISTINCT visit_id
    FROM events
    WHERE event_type = 3)
SELECT 
		ph.page_name AS product_name,
		COUNT(*) AS purchase_count
FROM events e
JOIN purchased_visits pv ON e.visit_id = pv.visit_id
JOIN page_hierarchy ph ON e.page_id = ph.page_id
WHERE ph.product_category IS NOT NULL AND e.event_type = 2
GROUP BY ph.page_name
ORDER BY purchase_count DESC
LIMIT 3;

C. Product Funnel Analysis

Using a single SQL query - create a new output table which has the following details:
How many times was each product viewed?
How many times was each product added to cart?
How many times was each product added to a cart but not purchased (abandoned)?
How many times was each product purchased?

CREATE TABLE Product_Funnel_Analysis
WITH CTE1 AS
(SELECT DISTINCT e.visit_id
    FROM events e
    JOIN event_identifier ei
        ON e.event_type = ei.event_type
    WHERE ei.event_name = 'purchase')
SELECT
    ph.page_name,
    SUM(CASE WHEN ei.event_name = 'page_view' THEN 1 ELSE 0 END) AS viewed,
    SUM(CASE WHEN ei.event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS added_to_cart,
    SUM(CASE WHEN ei.event_name = 'add_to_cart' AND e.visit_id NOT IN (SELECT visit_id FROM CTE1) THEN 1 ELSE 0 END) AS abandoned,
    SUM(CASE WHEN ei.event_name = 'add_to_cart' AND e.visit_id IN (SELECT visit_id FROM CTE1) THEN 1 ELSE 0 END) AS purchased
FROM events e
JOIN event_identifier ei
    ON e.event_type = ei.event_type
JOIN page_hierarchy ph
    ON e.page_id = ph.page_id
WHERE ph.product_id IS NOT NULL
GROUP BY ph.page_name
ORDER BY ph.page_name;


Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.

CREATE TABLE Product_Funnel_Analysis_2
WITH CTE1 AS
(SELECT DISTINCT e.visit_id
    FROM events e
    JOIN event_identifier ei
        ON e.event_type = ei.event_type
    WHERE ei.event_name = 'purchase')
SELECT
    ph.product_Category,
    SUM(CASE WHEN ei.event_name = 'page_view' THEN 1 ELSE 0 END) AS viewed,
    SUM(CASE WHEN ei.event_name = 'add_to_cart' THEN 1 ELSE 0 END) AS added_to_cart,
    SUM(CASE WHEN ei.event_name = 'add_to_cart' AND e.visit_id NOT IN (SELECT visit_id FROM CTE1) THEN 1 ELSE 0 END) AS abandoned,
    SUM(CASE WHEN ei.event_name = 'add_to_cart' AND e.visit_id IN (SELECT visit_id FROM CTE1) THEN 1 ELSE 0 END) AS purchased
FROM events e
JOIN event_identifier ei
    ON e.event_type = ei.event_type
JOIN page_hierarchy ph
    ON e.page_id = ph.page_id
WHERE ph.product_Category IS NOT NULL
GROUP BY ph.product_Category
ORDER BY ph.product_Category;

Use your 2 new output tables - answer the following questions:

1. Which product had the most views, cart adds and purchases?

SELECT product_category, viewed
FROM Product_Funnel_Analysis_2
WHERE viewed = (SELECT MAX(viewed) FROM Product_Funnel_Analysis_2)
Union All
SELECT product_category, added_to_cart
FROM Product_Funnel_Analysis_2
WHERE added_to_cart = (SELECT MAX(added_to_cart) FROM Product_Funnel_Analysis_2)
Union All
SELECT product_category, purchased
FROM Product_Funnel_Analysis_2
WHERE purchased = (SELECT MAX(purchased) FROM Product_Funnel_Analysis_2)

2. Which product was most likely to be abandoned?

SELECT 
    page_name,
    IFNULL(abandoned * 100.0 / NULLIF(added_to_cart, 0), 0) AS abandoned_pct
FROM Product_Funnel_Analysis
ORDER BY abandoned_pct DESC
LIMIT 1;

3. Which product had the highest view to purchase percentage?

SELECT 
    page_name,
    IFNULL(purchased * 100.0 / NULLIF(Viewed, 0), 0) AS Purchased_pct
FROM Product_Funnel_Analysis
ORDER BY Purchased_pct DESC
LIMIT 1;

4. What is the average conversion rate from view to cart add?

SELECT 
    ROUND(
        IFNULL(SUM(added_to_cart) * 100.0 / NULLIF(SUM(viewed), 0), 0)
    ,2) AS avg_conversion_rate
FROM Product_Funnel_Analysis;

5. What is the average conversion rate from cart add to purchase?

SELECT 
    ROUND(
        IFNULL(SUM(purchased) * 100.0 / NULLIF(SUM(added_to_cart), 0), 0)
    ,2) AS avg_conversion_rate
FROM Product_Funnel_Analysis;

D. Campaigns Analysis

Generate a table that has 1 single row for every unique visit_id record and has the following columns:
user_id
visit_id
visit_start_time: the earliest event_time for each visit
page_views: count of page views for each visit
cart_adds: count of product cart add events for each visit

Select 
	U.user_id,
	E.visit_id,
	Min(E.event_time) As Earliest_Event_Time,
	Count(E.page_id) As Page_views_for_each_visit,
	SUM(CASE WHEN E.event_type = 2 THEN 1 ELSE 0 END) AS Product_cart_add_events_for_each_visit,
    SUM(CASE WHEN E.event_type = 3 THEN 1 ELSE 0 END) AS Purchase_event_exists_for_each_visit
FROM users U JOIN events E ON U.cookie_id = E.cookie_id JOIN event_identifier EI ON E.event_type = EI.event_type
Group By U.user_id, E.Visit_id
ORDER BY U.user_id, E.Visit_id;

