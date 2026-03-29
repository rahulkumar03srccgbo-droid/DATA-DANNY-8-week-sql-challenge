A. Pizza Metrics
1. How many pizzas were ordered?
SELECT COUNT(*) AS pizzas_ordered
FROM customer_orders;

2. How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS unique_customer_orders
FROM customer_orders;

3. How many successful orders were delivered by each runner?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        runner_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
)
SELECT
    runner_id,
    COUNT(order_id) AS successful_orders
FROM runner_orders_clean
WHERE pickup_time IS NOT NULL
GROUP BY runner_id
ORDER BY runner_id;

4. How many of each type of pizza was delivered?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
)
SELECT
    pn.pizza_name,
    COUNT(*) AS delivered_count
FROM customer_orders co
JOIN runner_orders_clean roc
    ON co.order_id = roc.order_id
JOIN pizza_names pn
    ON co.pizza_id = pn.pizza_id
WHERE roc.pickup_time IS NOT NULL
GROUP BY pn.pizza_name
ORDER BY pn.pizza_name;

5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT
    customer_id,
    SUM(CASE WHEN pizza_id = 1 THEN 1 ELSE 0 END) AS meatlovers,
    SUM(CASE WHEN pizza_id = 2 THEN 1 ELSE 0 END) AS vegetarian
FROM customer_orders
GROUP BY customer_id
ORDER BY customer_id;

6. What was the maximum number of pizzas delivered in a single order?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
)
SELECT MAX(pizza_count) AS max_pizzas_delivered
FROM (
    SELECT
        co.order_id,
        COUNT(*) AS pizza_count
    FROM customer_orders co
    JOIN runner_orders_clean roc
        ON co.order_id = roc.order_id
    WHERE roc.pickup_time IS NOT NULL
    GROUP BY co.order_id
) t;

7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
),
customer_orders_clean AS (
    SELECT
        order_id,
        customer_id,
        pizza_id,
        CASE
            WHEN exclusions = '' OR exclusions = 'null' OR exclusions IS NULL THEN NULL
            ELSE exclusions
        END AS exclusions,
        CASE
            WHEN extras = '' OR extras = 'null' OR extras IS NULL THEN NULL
            ELSE extras
        END AS extras
    FROM customer_orders
)
SELECT
    coc.customer_id,
    SUM(CASE WHEN coc.exclusions IS NOT NULL OR coc.extras IS NOT NULL THEN 1 ELSE 0 END) AS at_least_1_change,
    SUM(CASE WHEN coc.exclusions IS NULL AND coc.extras IS NULL THEN 1 ELSE 0 END) AS no_change
FROM customer_orders_clean coc
JOIN runner_orders_clean roc
    ON coc.order_id = roc.order_id
WHERE roc.pickup_time IS NOT NULL
GROUP BY coc.customer_id
ORDER BY coc.customer_id;

8. How many pizzas were delivered that had both exclusions and extras?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
),
customer_orders_clean AS (
    SELECT
        order_id,
        customer_id,
        pizza_id,
        CASE
            WHEN exclusions = '' OR exclusions = 'null' OR exclusions IS NULL THEN NULL
            ELSE exclusions
        END AS exclusions,
        CASE
            WHEN extras = '' OR extras = 'null' OR extras IS NULL THEN NULL
            ELSE extras
        END AS extras
    FROM customer_orders
)
SELECT COUNT(*) AS pizzas_with_both
FROM customer_orders_clean coc
JOIN runner_orders_clean roc
    ON coc.order_id = roc.order_id
WHERE roc.pickup_time IS NOT NULL
  AND coc.exclusions IS NOT NULL
  AND coc.extras IS NOT NULL;
  
9. What was the total volume of pizzas ordered for each hour of the day?
SELECT
    HOUR(order_time) AS hour_of_day,
    COUNT(*) AS pizza_volume
FROM customer_orders
GROUP BY HOUR(order_time)
ORDER BY HOUR(order_time);

10. What was the volume of orders for each day of the week?
SELECT
    DAYNAME(order_time) AS day_of_week,
    COUNT(DISTINCT order_id) AS order_volume
FROM customer_orders
GROUP BY DAYNAME(order_time)
ORDER BY FIELD(DAYNAME(order_time),
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');
    
B. Runner and Customer Experience
1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT
    DAYNAME(order_time) AS day_of_week,
    COUNT(DISTINCT order_id) AS order_volume
FROM customer_orders
GROUP BY DAYNAME(order_time)
ORDER BY FIELD(DAYNAME(order_time),
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday');
    
2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        runner_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
),
order_time_cte AS (
    SELECT
        order_id,
        MIN(order_time) AS order_time
    FROM customer_orders
    GROUP BY order_id
)
SELECT
    roc.runner_id,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, otc.order_time, roc.pickup_time)), 2) AS avg_pickup_minutes
FROM runner_orders_clean roc
JOIN order_time_cte otc
    ON roc.order_id = otc.order_id
WHERE roc.pickup_time IS NOT NULL
GROUP BY roc.runner_id
ORDER BY roc.runner_id;

3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
),
order_pizza_count AS (
    SELECT
        order_id,
        MIN(order_time) AS order_time,
        COUNT(*) AS pizza_count
    FROM customer_orders
    GROUP BY order_id
)
SELECT
    opc.pizza_count,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, opc.order_time, roc.pickup_time)), 2) AS avg_prep_time
FROM order_pizza_count opc
JOIN runner_orders_clean roc
    ON opc.order_id = roc.order_id
WHERE roc.pickup_time IS NOT NULL
GROUP BY opc.pizza_count
ORDER BY opc.pizza_count;

4. What was the average distance travelled for each customer?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time,
        CASE
            WHEN distance = 'null' OR distance IS NULL THEN NULL
            ELSE CAST(REGEXP_REPLACE(distance, '[^0-9.]', '') AS DECIMAL(5,2))
        END AS distance_km
    FROM runner_orders
),
customer_order_distinct AS (
    SELECT DISTINCT
        co.order_id,
        co.customer_id
    FROM customer_orders co
)
SELECT
    cod.customer_id,
    ROUND(AVG(roc.distance_km), 2) AS avg_distance
FROM customer_order_distinct cod
JOIN runner_orders_clean roc
    ON cod.order_id = roc.order_id
WHERE roc.pickup_time IS NOT NULL
GROUP BY cod.customer_id
ORDER BY cod.customer_id;

5. What was the difference between the longest and shortest delivery times for all orders?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN duration = 'null' OR duration IS NULL THEN NULL
            ELSE CAST(REGEXP_REPLACE(duration, '[^0-9]', '') AS UNSIGNED)
        END AS duration_mins,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
)
SELECT
    MAX(duration_mins) - MIN(duration_mins) AS diff_between_longest_shortest
FROM runner_orders_clean
WHERE pickup_time IS NOT NULL;

6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        runner_id,
        CASE
            WHEN distance = 'null' OR distance IS NULL THEN NULL
            ELSE CAST(REGEXP_REPLACE(distance, '[^0-9.]', '') AS DECIMAL(5,2))
        END AS distance_km,
        CASE
            WHEN duration = 'null' OR duration IS NULL THEN NULL
            ELSE CAST(REGEXP_REPLACE(duration, '[^0-9]', '') AS UNSIGNED)
        END AS duration_mins,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
)
SELECT
    runner_id,
    order_id,
    distance_km,
    duration_mins,
    ROUND(distance_km / duration_mins * 60, 2) AS avg_speed_kmph
FROM runner_orders_clean
WHERE pickup_time IS NOT NULL
ORDER BY runner_id, order_id;

7. What is the successful delivery percentage for each runner?
WITH runner_orders_clean AS (
    SELECT
        order_id,
        runner_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time
    FROM runner_orders
)
SELECT
    runner_id,
    COUNT(CASE WHEN pickup_time IS NOT NULL THEN 1 END) AS successful_orders,
    COUNT(*) AS total_orders,
    ROUND(COUNT(CASE WHEN pickup_time IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) AS success_percentage
FROM runner_orders_clean
GROUP BY runner_id
ORDER BY runner_id;

C. Ingredient Optimisation
1. What are the standard ingredients for each pizza?

SELECT
    pn.pizza_name,
    GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_name SEPARATOR ', ') AS standard_ingredients
FROM pizza_recipes pr
JOIN pizza_names pn
    ON pr.pizza_id = pn.pizza_id
JOIN JSON_TABLE(CONCAT('[', pr.toppings, ']'),'$[*]' COLUMNS (topping_id INT PATH '$')) jt
JOIN pizza_toppings pt
    ON jt.topping_id = pt.topping_id
GROUP BY pn.pizza_name
ORDER BY pn.pizza_id;

2. What was the most commonly added extra?
SELECT
    pn.pizza_name,
    GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_name SEPARATOR ', ') AS standard_ingredients
FROM pizza_recipes pr
JOIN pizza_names pn
    ON pr.pizza_id = pn.pizza_id
JOIN JSON_TABLE(
    CONCAT('[', pr.toppings, ']'),
    '$[*]' COLUMNS (
        topping_id INT PATH '$'
    )
) jt
JOIN pizza_toppings pt
    ON jt.topping_id = pt.topping_id
GROUP BY pn.pizza_name
ORDER BY pn.pizza_id;

3. What was the most common exclusion?
WITH delivered AS (
    SELECT co.order_id, co.exclusions
    FROM customer_orders co
    JOIN runner_orders ro
        ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
       OR ro.cancellation = ''
       OR ro.cancellation = 'null'
)
SELECT
    pt.topping_name,
    COUNT(*) AS exclusion_count
FROM delivered d
JOIN JSON_TABLE(
    CONCAT('[', REPLACE(d.exclusions, ' ', ''), ']'),
    '$[*]' COLUMNS (
        topping_id INT PATH '$'
    )
) jt
JOIN pizza_toppings pt
    ON jt.topping_id = pt.topping_id
WHERE d.exclusions IS NOT NULL
  AND d.exclusions <> ''
  AND d.exclusions <> 'null'
GROUP BY pt.topping_name
ORDER BY exclusion_count DESC
LIMIT 1;

4. Generate an order item for each record in the customers_orders table in the format of one of the following:
Meat Lovers
Meat Lovers - Exclude Beef
Meat Lovers - Extra Bacon
Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH base AS (
    SELECT
        co.order_id,
        co.customer_id,
        co.pizza_id,
        pn.pizza_name,
        CASE
            WHEN co.exclusions IS NULL OR co.exclusions = '' OR co.exclusions = 'null' THEN NULL
            ELSE REPLACE(co.exclusions, ' ', '')
        END AS exclusions,
        CASE
            WHEN co.extras IS NULL OR co.extras = '' OR co.extras = 'null' THEN NULL
            ELSE REPLACE(co.extras, ' ', '')
        END AS extras
    FROM customer_orders co
    JOIN pizza_names pn
        ON co.pizza_id = pn.pizza_id
),
exclusions_cte AS (
    SELECT
        b.order_id,
        b.customer_id,
        b.pizza_id,
        GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_name SEPARATOR ', ') AS exclusion_list
    FROM base b
    JOIN JSON_TABLE(
        CONCAT('[', b.exclusions, ']'),
        '$[*]' COLUMNS (
            topping_id INT PATH '$'
        )
    ) jt
    JOIN pizza_toppings pt
        ON jt.topping_id = pt.topping_id
    WHERE b.exclusions IS NOT NULL
    GROUP BY b.order_id, b.customer_id, b.pizza_id
),
extras_cte AS (
    SELECT
        b.order_id,
        b.customer_id,
        b.pizza_id,
        GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_name SEPARATOR ', ') AS extra_list
    FROM base b
    JOIN JSON_TABLE(
        CONCAT('[', b.extras, ']'),
        '$[*]' COLUMNS (
            topping_id INT PATH '$'
        )
    ) jt
    JOIN pizza_toppings pt
        ON jt.topping_id = pt.topping_id
    WHERE b.extras IS NOT NULL
    GROUP BY b.order_id, b.customer_id, b.pizza_id
)
SELECT
    b.order_id,
    b.customer_id,
    CONCAT(
        b.pizza_name,
        CASE
            WHEN e.exclusion_list IS NOT NULL THEN CONCAT(' - Exclude ', e.exclusion_list)
            ELSE ''
        END,
        CASE
            WHEN x.extra_list IS NOT NULL THEN CONCAT(' - Extra ', x.extra_list)
            ELSE ''
        END
    ) AS order_item
FROM base b
LEFT JOIN exclusions_cte e
    ON b.order_id = e.order_id
   AND b.customer_id = e.customer_id
   AND b.pizza_id = e.pizza_id
LEFT JOIN extras_cte x
    ON b.order_id = x.order_id
   AND b.customer_id = x.customer_id
   AND b.pizza_id = x.pizza_id
ORDER BY b.order_id, b.customer_id, b.pizza_id;

5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH base AS (
    SELECT
        co.order_id,
        co.customer_id,
        co.pizza_id,
        pn.pizza_name,
        CASE
            WHEN co.exclusions IS NULL OR co.exclusions = '' OR co.exclusions = 'null' THEN NULL
            ELSE REPLACE(co.exclusions, ' ', '')
        END AS exclusions,
        CASE
            WHEN co.extras IS NULL OR co.extras = '' OR co.extras = 'null' THEN NULL
            ELSE REPLACE(co.extras, ' ', '')
        END AS extras
    FROM customer_orders co
    JOIN pizza_names pn
        ON co.pizza_id = pn.pizza_id
),
exclusions_cte AS (
    SELECT
        b.order_id,
        b.customer_id,
        b.pizza_id,
        GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_name SEPARATOR ', ') AS exclusion_list
    FROM base b
    JOIN JSON_TABLE(
        CONCAT('[', b.exclusions, ']'),
        '$[*]' COLUMNS (
            topping_id INT PATH '$'
        )
    ) jt
    JOIN pizza_toppings pt
        ON jt.topping_id = pt.topping_id
    WHERE b.exclusions IS NOT NULL
    GROUP BY b.order_id, b.customer_id, b.pizza_id
),
extras_cte AS (
    SELECT
        b.order_id,
        b.customer_id,
        b.pizza_id,
        GROUP_CONCAT(pt.topping_name ORDER BY pt.topping_name SEPARATOR ', ') AS extra_list
    FROM base b
    JOIN JSON_TABLE(
        CONCAT('[', b.extras, ']'),
        '$[*]' COLUMNS (
            topping_id INT PATH '$'
        )
    ) jt
    JOIN pizza_toppings pt
        ON jt.topping_id = pt.topping_id
    WHERE b.extras IS NOT NULL
    GROUP BY b.order_id, b.customer_id, b.pizza_id
)
SELECT
    b.order_id,
    b.customer_id,
    CONCAT(
        b.pizza_name,
        CASE
            WHEN e.exclusion_list IS NOT NULL THEN CONCAT(' - Exclude ', e.exclusion_list)
            ELSE ''
        END,
        CASE
            WHEN x.extra_list IS NOT NULL THEN CONCAT(' - Extra ', x.extra_list)
            ELSE ''
        END
    ) AS order_item
FROM base b
LEFT JOIN exclusions_cte e
    ON b.order_id = e.order_id
   AND b.customer_id = e.customer_id
   AND b.pizza_id = e.pizza_id
LEFT JOIN extras_cte x
    ON b.order_id = x.order_id
   AND b.customer_id = x.customer_id
   AND b.pizza_id = x.pizza_id
ORDER BY b.order_id, b.customer_id, b.pizza_id;

6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

WITH base_orders AS (
    SELECT
        co.order_id,
        co.customer_id,
        co.pizza_id,
        pn.pizza_name,
        CASE
            WHEN co.exclusions IS NULL OR co.exclusions = '' OR co.exclusions = 'null' THEN NULL
            ELSE REPLACE(co.exclusions, ' ', '')
        END AS exclusions,
        CASE
            WHEN co.extras IS NULL OR co.extras = '' OR co.extras = 'null' THEN NULL
            ELSE REPLACE(co.extras, ' ', '')
        END AS extras
    FROM customer_orders co
    JOIN pizza_names pn
        ON co.pizza_id = pn.pizza_id
),
recipe_toppings AS (
    SELECT
        bo.order_id,
        bo.customer_id,
        bo.pizza_id,
        bo.pizza_name,
        jt.topping_id
    FROM base_orders bo
    JOIN pizza_recipes pr
        ON bo.pizza_id = pr.pizza_id
    JOIN JSON_TABLE(
        CONCAT('[', pr.toppings, ']'),
        '$[*]' COLUMNS (
            topping_id INT PATH '$'
        )
    ) jt
),
excluded_toppings AS (
    SELECT
        bo.order_id,
        bo.customer_id,
        bo.pizza_id,
        jt.topping_id
    FROM base_orders bo
    JOIN JSON_TABLE(
        CONCAT('[', bo.exclusions, ']'),
        '$[*]' COLUMNS (
            topping_id INT PATH '$'
        )
    ) jt
    WHERE bo.exclusions IS NOT NULL
),
extra_toppings AS (
    SELECT
        bo.order_id,
        bo.customer_id,
        bo.pizza_id,
        jt.topping_id
    FROM base_orders bo
    JOIN JSON_TABLE(
        CONCAT('[', bo.extras, ']'),
        '$[*]' COLUMNS (
            topping_id INT PATH '$'
        )
    ) jt
    WHERE bo.extras IS NOT NULL
),
base_after_exclusion AS (
    SELECT
        rt.order_id,
        rt.customer_id,
        rt.pizza_id,
        rt.pizza_name,
        rt.topping_id
    FROM recipe_toppings rt
    LEFT JOIN excluded_toppings et
        ON rt.order_id = et.order_id
       AND rt.customer_id = et.customer_id
       AND rt.pizza_id = et.pizza_id
       AND rt.topping_id = et.topping_id
    WHERE et.topping_id IS NULL
),
all_toppings AS (
    SELECT
        order_id,
        customer_id,
        pizza_id,
        pizza_name,
        topping_id,
        1 AS qty
    FROM base_after_exclusion

    UNION ALL

    SELECT
        bo.order_id,
        bo.customer_id,
        bo.pizza_id,
        bo.pizza_name,
        et.topping_id,
        1 AS qty
    FROM extra_toppings et
    JOIN base_orders bo
        ON et.order_id = bo.order_id
       AND et.customer_id = bo.customer_id
       AND et.pizza_id = bo.pizza_id
),
final_counts AS (
    SELECT
        order_id,
        customer_id,
        pizza_id,
        pizza_name,
        topping_id,
        COUNT(*) AS topping_qty
    FROM all_toppings
    GROUP BY order_id, customer_id, pizza_id, pizza_name, topping_id
)
SELECT
    order_id,
    customer_id,
    CONCAT(
        pizza_name, ': ',
        GROUP_CONCAT(
            CASE
                WHEN topping_qty > 1 THEN CONCAT(topping_qty, 'x', pt.topping_name)
                ELSE pt.topping_name
            END
            ORDER BY pt.topping_name
            SEPARATOR ', '
        )
    ) AS ingredient_list
FROM final_counts fc
JOIN pizza_toppings pt
    ON fc.topping_id = pt.topping_id
GROUP BY order_id, customer_id, pizza_id, pizza_name
ORDER BY order_id, customer_id, pizza_id;

D. Pricing and Ratings
1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

WITH delivered_orders AS (
    SELECT
        co.order_id,
        co.pizza_id
    FROM customer_orders co
    JOIN runner_orders ro
        ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
       OR ro.cancellation = ''
       OR ro.cancellation = 'null'
)
SELECT
    SUM(
        CASE
            WHEN pizza_id = 1 THEN 12
            WHEN pizza_id = 2 THEN 10
        END
    ) AS total_revenue
FROM delivered_orders;

2. What if there was an additional $1 charge for any pizza extras?
Add cheese is $1 extra

WITH delivered_orders AS (
    SELECT
        co.order_id,
        co.pizza_id
    FROM customer_orders co
    JOIN runner_orders ro
        ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
       OR ro.cancellation = ''
       OR ro.cancellation = 'null'
)
SELECT
    SUM(
        CASE
            WHEN pizza_id = 1 THEN 12
            WHEN pizza_id = 2 THEN 10
        END
    ) AS total_revenue
FROM delivered_orders;

3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

CREATE TABLE ratings (
    rating_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    customer_id INT NOT NULL,
    runner_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    rating_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO ratings (order_id, customer_id, runner_id, rating)
VALUES
(1, 101, 1, 5),
(2, 101, 1, 4),
(3, 102, 1, 5),
(4, 103, 2, 3),
(5, 104, 3, 4),
(7, 105, 2, 5),
(8, 102, 2, 4),
(10, 104, 1, 5);




4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
customer_id
order_id
runner_id
rating
order_time
pickup_time
Time between order and pickup
Delivery duration
Average speed
Total number of pizzas

WITH runner_orders_clean AS (
    SELECT
        order_id,
        runner_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time,
        CAST(REGEXP_REPLACE(distance, '[^0-9.]', '') AS DECIMAL(5,2)) AS distance_km,
        CAST(REGEXP_REPLACE(duration, '[^0-9]', '') AS UNSIGNED) AS duration_mins,
        cancellation
    FROM runner_orders
),
order_summary AS (
    SELECT
        order_id,
        customer_id,
        MIN(order_time) AS order_time,
        COUNT(*) AS total_pizzas
    FROM customer_orders
    GROUP BY order_id, customer_id
)
SELECT
    os.customer_id,
    os.order_id,
    roc.runner_id,
    r.rating,
    os.order_time,
    roc.pickup_time,
    TIMESTAMPDIFF(MINUTE, os.order_time, roc.pickup_time) AS time_between_order_and_pickup,
    roc.duration_mins AS delivery_duration,
    ROUND(roc.distance_km / roc.duration_mins * 60, 2) AS average_speed,
    os.total_pizzas
FROM order_summary os
JOIN runner_orders_clean roc
    ON os.order_id = roc.order_id
LEFT JOIN ratings r
    ON os.order_id = r.order_id
WHERE roc.cancellation IS NULL
   OR roc.cancellation = ''
   OR roc.cancellation = 'null'
ORDER BY os.order_id;


5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

WITH runner_orders_clean AS (
    SELECT
        order_id,
        CASE
            WHEN pickup_time = 'null' OR pickup_time IS NULL THEN NULL
            ELSE CAST(pickup_time AS DATETIME)
        END AS pickup_time,
        CAST(REGEXP_REPLACE(distance, '[^0-9.]', '') AS DECIMAL(5,2)) AS distance_km,
        cancellation
    FROM runner_orders
),
revenue_cte AS (
    SELECT
        SUM(
            CASE
                WHEN co.pizza_id = 1 THEN 12
                WHEN co.pizza_id = 2 THEN 10
            END
        ) AS total_revenue
    FROM customer_orders co
    JOIN runner_orders_clean roc
        ON co.order_id = roc.order_id
    WHERE roc.cancellation IS NULL
       OR roc.cancellation = ''
       OR roc.cancellation = 'null'
),
runner_cost_cte AS (
    SELECT
        SUM(distance_km * 0.30) AS total_runner_cost
    FROM runner_orders_clean
    WHERE cancellation IS NULL
       OR cancellation = ''
       OR cancellation = 'null'
)
SELECT
    total_revenue,
    total_runner_cost,
    ROUND(total_revenue - total_runner_cost, 2) AS money_left
FROM revenue_cte
CROSS JOIN runner_cost_cte;
