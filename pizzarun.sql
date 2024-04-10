-- Remove rows with null values in runner_id
DELETE FROM runner_orders
WHERE runner_id IS NULL;

-- Fill null values in pickup_time, distance, and duration columns
UPDATE runner_orders
SET pickup_time = COALESCE(pickup_time, 'N/A'),
    distance = COALESCE(distance, 'N/A'),
    duration = COALESCE(duration, 'N/A'),
    cancellation = COALESCE(cancellation, 'Delivered');

-- Remove duplicate rows
DELETE FROM customer_orders
WHERE order_id IN (
    SELECT order_id
    FROM (
        SELECT order_id, ROW_NUMBER() OVER(PARTITION BY order_id ORDER BY order_time) AS row_num
        FROM customer_orders
    ) t
    WHERE row_num > 1
);

-- Fill in missing values with appropriate defaults
UPDATE customer_orders
SET exclusions = COALESCE(exclusions, 'None'),
    extras = COALESCE(extras, 'None'),
    pizza_id = COALESCE(pizza_id, 0);

-- Standardize date format
UPDATE customer_orders
SET order_time = CAST(order_time AS TIMESTAMP);




--How many pizzas were ordered?
SELECT Count(pizza_id)
FROM customer_orders;

--How many unique customer orders were made?
WITH t1 As (SELECT DISTINCT(ci.order_id)
			FROM customer_orders ci
			JOIN runner_orders r
			ON ci.order_id = r.order_id)

SELECT COUNT(*)
FROM t1;


--How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(*)
FROM runner_orders r
WHERE cancellation NOT LIKE '% Cancellation'
GROUP BY runner_id;


--How many of each type of pizza was delivered?
SELECT p.pizza_name, COUNT(ro.order_id) AS pizzas_delivered
FROM runner_orders ro
JOIN customer_orders co ON ro.order_id = co.order_id
JOIN pizza_names p ON co.pizza_id = p.pizza_id
WHERE ro.cancellation NOT LIKE '% Cancellation'
GROUP BY p.pizza_name;



--How many Vegetarian and Meatlovers were ordered by each customer
SELECT customer_id, pizza_name, count(pizza_name) AS counts
FROM customer_orders co
JOIN pizza_names pn
ON co.pizza_id = pn.pizza_id
GROUP BY customer_id, pizza_name;


--What was the maximum number of pizzas delivered in a single order?
WITH t2 AS (SELECT order_time, COUNT(pizza_id) AS counts
			FROM customer_orders ci
			JOIN runner_orders r
			ON ci.order_id = r.order_id
			WHERE cancellation NOT LIKE '% Cancellation'
			GROUP BY order_time)
SELECT MAX(counts)
FROM t2;



--For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
WITH cleaned_orders AS (
    SELECT
        order_id,
        customer_id,
        pizza_id,
        COALESCE(NULLIF(exclusions, 'null'), '') AS cleaned_exclusions,
        COALESCE(NULLIF(extras, 'null'), '') AS cleaned_extras
    FROM customer_orders
),
orders_with_changes AS (
    SELECT
        order_id,
        customer_id,
        pizza_id
    FROM cleaned_orders
    WHERE cleaned_exclusions <> '' OR cleaned_extras <> ''
),
orders_no_changes AS (
    SELECT
        order_id,
        customer_id,
        pizza_id
    FROM cleaned_orders
    WHERE cleaned_exclusions = '' AND cleaned_extras = ''
)
SELECT
    'Orders with Changes' AS order_type,
    COUNT(DISTINCT order_id) AS count_orders
FROM orders_with_changes
UNION ALL
SELECT
    'Orders with No Changes' AS order_type,
    COUNT(DISTINCT order_id) AS count_orders
FROM orders_no_changes;

--How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(*) AS pizzas_with_exclusions_and_extras
FROM runner_orders ro
JOIN customer_orders co ON ro.order_id = co.order_id 
WHERE ro.cancellation NOT LIKE '% Cancellation'
AND co.exclusions IS NOT NULL
AND co.extras IS NOT NULL;


---What was the total volume of pizzas ordered for each hour of the day?
SELECT EXTRACT(HOUR FROM order_time) AS order_hour,
    COUNT(*) AS total_orders
FROM customer_orders
GROUP BY EXTRACT(HOUR FROM order_time)
ORDER BY order_hour;


---What was the volume of orders for each day of the week?
SELECT EXTRACT(Dow FROM order_time) AS order_day_of_week,
    COUNT(*) AS total_orders
FROM customer_orders
GROUP BY EXTRACT(Dow FROM order_time)
ORDER BY order_day_of_week;


--How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT DATE_TRUNC('week', registration_date) AS week_start,
    COUNT(*) AS new_runners
FROM runners
WHERE registration_date >= '2021-01-01'
GROUP BY DATE_TRUNC('week', registration_date)
ORDER BY week_start;

--What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT r.runner_id, AVG(EXTRACT(MINUTE FROM TO_TIMESTAMP(r.pickup_time, 'YYYY-MM-DD HH24:MI:SS') - cu.order_time)) AS average_time_of_arrival
FROM runner_orders r
JOIN customer_orders cu
ON r.order_id = cu.order_id
GROUP BY r.runner_id;

--Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH order_summary AS (SELECT COUNT(*) AS total_pizzas, EXTRACT(MINUTE FROM TO_TIMESTAMP(r.pickup_time, 'YYYY-MM-DD HH24:MI:SS') - cu.order_time) diff
    					FROM runner_orders r
					    JOIN customer_orders cu ON r.order_id = cu.order_id
    					GROUP BYnr.pickup_time, cu.order_time)
SELECT CORR(total_pizzas, diff) AS correlation_coefficient
FROM order_summary;


--What was the average distance travelled for each customer?
SELECT co.customer_id, AVG(CAST(REPLACE(r.distance, 'km', '') AS FLOAT)) AS average_distance
FROM customer_orders co
JOIN runner_orders r
ON co.order_id = r.order_id
GROUP BY co.customer_id, r.distance;


--What was the difference between the longest and shortest delivery times for all orders?
SELECT
	   MAX(CAST(r.pickup_time AS timestamp)-co.order_time)-MIN(CAST(r.pickup_time AS timestamp)-co.order_time) AS diff_max_min
FROM runner_orders r
JOIN customer_orders co
ON r.order_id = co.order_id
WHERE r.pickup_time IS NOT NULL AND co.order_time IS NOT NULL;


--What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT 
    r.runner_id,
    r.order_id,
    r.distance,
    r.duration,
    AVG(CAST(REPLACE(r.distance, 'km', '') AS FLOAT) / CAST(REPLACE(REPLACE(REPLACE(r.duration, 'mins', ''), 'minutes', ''), 'minute', '') AS NUMERIC)) AS average_speed
FROM runner_orders r
JOIN customer_orders cu ON r.order_id = cu.order_id
GROUP BY 1,2,3,4;


--What are the standard ingredients for each pizza?
SELECT topping_name
FROM ;

--What are the standard ingredients for each pizza?
SELECT ARRAY_AGG(topping_name) AS standard_ingredients
FROM pizza_toppings;

--What was the most commonly added extra?
SELECT extras, COUNT(*) AS count_extras
FROM customer_orders
WHERE extras != 'null' AND extras != '' 
GROUP BY extras
ORDER BY count_extras DESC
LIMIT 1;

--What was the most common exclusion?
SELECT exclusions
FROM customer_orders
WHERE exclusions != 'null' AND exclusions != '' 
GROUP BY exclusions
ORDER BY count_extras DESC
LIMIT 1;


--Generate an order item for each record in the customers_orders table in the format of one of the following:
--Meat Lovers
--Meat Lovers - Exclude Beef
--Meat Lovers - Extra Bacon
--Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

SELECT *, CASE
				WHEN pizza_name = 'Meatlovers' AND exclusions = 'null' AND extras = 'null'
				THEN 'Meatlovers'
				WHEN pizza_name = 'Meatlovers' AND extras = '1'
				THEN 'Meat Lovers - Extra Bacon'
				WHEN pizza_name = 'Meatlovers' AND exclusions = '3'
				THEN 'Meat Lovers - Exclude Beef'
				WHEN pizza_name = 'Meatlovers' AND exclusions = '4,1' AND extras = '6,9'
				THEN 'Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers'
			ELSE pizza_names.pizza_name
			END AS order_item
FROM customer_orders
JOIN pizza_names
ON customer_orders.pizza_id = pizza_names.pizza_id;

--What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
SELECT pt.topping_name, SUM(CASE
      							WHEN pt.topping_name IS NOT NULL THEN 1
      						ELSE 0
    						END) AS total_quantity
FROM customer_orders co
JOIN pizza_recipes pr 
ON co.pizza_id = pr.pizza_id
LEFT JOIN LATERAL (SELECT UNNEST(STRING_TO_ARRAY(pr.toppings, ', ')::INT[]) AS topping_id) AS topping_id_list ON true
LEFT JOIN pizza_toppings pt 
ON pt.topping_id = topping_id_list.topping_id
GROUP BY pt.topping_name
ORDER BY total_quantity DESC;


--If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
WITH pizza_costs AS (
  SELECT
    co.pizza_id,
    CASE
      WHEN pn.pizza_name = 'Meatlovers' THEN 12
      WHEN pn.pizza_name = 'Vegetarian' THEN 10
      ELSE 0
    END AS pizza_cost
  FROM customer_orders co
  JOIN pizza_names pn 
  ON co.pizza_id = pn.pizza_id
)
SELECT SUM(pc.pizza_cost) AS total_revenue
FROM pizza_costs pc;


--What if there was an additional $1 charge for any pizza extras?
Add cheese is $1 extra
WITH pizza_costs AS (
  SELECT
    co.pizza_id,
    CASE
      WHEN pn.pizza_name = 'Meatlovers' THEN 12
      WHEN pn.pizza_name = 'Vegetarian' THEN 10
      ELSE 0
    END AS base_pizza_cost,
    CASE
      WHEN co.extras LIKE '%1%' THEN 1 -- $1 extra for any extras
      ELSE 0
    END AS extra_charge
  FROM
    customer_orders co
  JOIN
    pizza_names pn ON co.pizza_id = pn.pizza_id
)
SELECT
  SUM(pc.base_pizza_cost + pc.extra_charge) AS total_revenue
FROM
  pizza_costs pc;


--The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
CREATE TABLE runner_ratings (
  "rating_id" SERIAL PRIMARY KEY,
  "order_id" INTEGER NOT NULL,
  "runner_id" INTEGER NOT NULL,
  "customer_id" INTEGER NOT NULL,
  "rating" INTEGER CHECK (rating >= 1 AND rating <= 5),
  "comment" TEXT,
  "rating_time" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO runner_ratings ("order_id", "runner_id", "customer_id", "rating", "comment")
VALUES
  (1, 1, 101, 4, 'Prompt delivery, good service.'),
  (2, 1, 101, 5, 'Excellent service, very friendly.'),
  (3, 2, 102, 3, 'Delivery was late but runner was polite.'),
  (4, 3, 103, 5, 'Great delivery, runner was very helpful.'),
  (5, 3, 103, 4, 'Good service overall.'),
  (6, 4, 104, 2, 'Delivery was slow and runner forgot napkins.');














