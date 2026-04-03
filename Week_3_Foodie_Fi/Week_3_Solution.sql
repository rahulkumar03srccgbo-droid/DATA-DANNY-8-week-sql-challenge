SELECT * FROM plans;
SELECT * FROM subscriptions;

B. Data Analysis Questions
1. How many customers has Foodie-Fi ever had?

SELECT Count(Distinct customer_id) as Total_Customer FROM subscriptions;


2. What is the monthly distribution of trial plan start_date values for our dataset 
- use the start of the month as the group by value

SELECT 
	DATE_SUB(start_date, INTERVAL DAY(start_date)-1 DAY) As Start_Month,
    Count(customer_id) AS Count_Customer
	FROM subscriptions 
    WHERE plan_id = 0
    GROUP BY Start_Month;

3. What plan start_date values occur after the year 2020 for our dataset? 
Show the breakdown by count of events for each plan_name

SELECT 
	plan_name,
    Count(S.plan_id) As Count_of_events
FROM subscriptions S JOIN plans P ON S.plan_id = P.plan_id WHERE s.start_date >= '2021-01-01'
GROUP BY plan_name;

4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?

WITH CTE1 AS
(SELECT 
	(SELECT Count(Distinct customer_id) FROM subscriptions) As Total_Count,
	Count(Distinct customer_id) As Churn_Count
    FROM subscriptions WHERE plan_id = 4)
SELECT Total_Count AS Customer_Count, 
		Round(Churn_Count*100/Total_Count, 1) As Percentage_Of_Customers 
	FROM CTE1;
    

5. How many customers have churned straight after their initial free trial 
- what percentage is this rounded to the nearest whole number?

WITH CTE1 AS
(SELECT 
	customer_id,
    plan_id,
    LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS Next_Plan
    FROM subscriptions),
CTE2 AS
(SELECT 
	Count(customer_id) As Churned_Straight
 FROM CTE1
    WHERE plan_id = 0 AND Next_Plan = 4)
SELECT 
	Churned_Straight,
	Round(Churned_Straight*100 / (SELECT Count(Distinct customer_id) From subscriptions),0) AS Perc_Churned
FROM CTE2;

6. What is the number and percentage of customer plans after their initial free trial?
WITH CTE1 AS
(SELECT 
	customer_id,
    plan_id,
    LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS Next_Plan
    FROM subscriptions)
SELECT 
	Next_plan,
    Count(customer_id) As Number_Count,
    Round(Count(customer_id)*100/ (SELECT Count(Distinct Customer_id) From subscriptions),2) As Perc_Plan
 FROM CTE1 
    WHERE plan_id = 0
    GROUP BY Next_Plan;
    
7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

SELECT * FROM plans;

WITH DATE_FILTER AS 
(SELECT * FROM subscriptions 
WHERE start_date <= '2020-12-31'),
Max_Date AS
(SELECT customer_id, max(start_date) As Max_Date FROM DATE_FILTER GROUP BY customer_id),
As_Req AS
(SELECT MD.customer_id, plan_id FROM Max_Date AS MD JOIN DATE_FILTER AS DF ON 
MD.customer_id = DF.customer_id AND MD.Max_date = DF.start_date),
CTE1 AS
(SELECT plan_id, Count(Distinct customer_id) As Count_Cust FROM AS_req GROUP BY Plan_id),
Total AS
(SELECT Sum(count_cust) AS Total FROM CTE1)
SELECT *, 
	Round(Count_cust*100/(SELECT Total FRom Total),2) As Perc FROM CTE1  
    
8. How many customers have upgraded to an annual plan in 2020?

SELECT Count(distinct customer_id) As Count_Cust FROM subscriptions WHERE year(start_date) = 2020 AND plan_id = 3;

WITH CTE1 AS
(SELECT *,
	LAG(plan_id) OVER (partition by Customer_id ORDER BY start_date ASC) AS Previous_Plan
    FROM subscriptions WHERE year(start_date) = 2020)
SELECT Count(Distinct customer_id) As Cust FROM CTE1 WHERE plan_id = 3 AND Previous_Plan is not null GROUP BY plan_id;

9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

WITH JD AS
	(SELECT customer_id, Min(start_date) as Joined_Date FROM subscriptions GROUP BY customer_id),
AVERAGE AS
(SELECT 
	S.customer_id,
    start_date,
    Joined_date,
    DATEDIFF(start_date,Joined_Date) AS Diff
    FROM Subscriptions S JOIN JD ON S.customer_id = JD.customer_id WHERE plan_id = 3)
SELECT Round(Avg(Diff),0) As Average FROM Average 


10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
 
WITH JD AS
	(SELECT customer_id, Min(start_date) as Joined_Date FROM subscriptions GROUP BY customer_id),
Difference AS
(SELECT 
	S.customer_id,
    start_date,
    Joined_date,
    DATEDIFF(start_date,Joined_Date) AS Diff
    FROM Subscriptions S JOIN JD ON S.customer_id = JD.customer_id WHERE plan_id = 3),
Bracket AS
(SELECT 
	customer_id,
    CASE 
    WHEN Diff >= 0 AND Diff <31 THEN "0-30"
    WHEN Diff >= 31 AND Diff <61 THEN "31-60"
    WHEN Diff >= 61 AND Diff <91 THEN "61-90"
    ELSE ">90" END AS Bracket
	FROM Difference)
Select Bracket, Count(customer_id) As Count_Cust FROM Bracket GROUP BY Bracket; 

11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

WITH CTE AS
(SELECT 
	customer_id, plan_id, start_date,
	LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS previous_plan
    FROM subscriptions)
SELECT COUNT(DISTINCT customer_id) AS count_cust_down
FROM CTE
WHERE plan_id = 1 AND previous_plan = 2 AND YEAR(start_date) = 2020;


12.
The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
once a customer churns they will no longer make payments

WITH RECURSIVE plans AS 
(SELECT 0 AS plan_id, 'trial' AS plan_name, 0 AS price UNION
    SELECT 1, 'basic monthly', 9.90 UNION
    SELECT 2, 'pro monthly', 19.90 UNION
    SELECT 3, 'pro annual', 199),
CTE1 AS 
(SELECT 
        customer_id,
        plan_id,
        start_date,
        LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_plan,
        LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_date
FROM subscriptions),
CTE2 AS 
(SELECT 
        c.customer_id,
        c.plan_id,
        p.price,
        c.start_date AS payment_date,
        c.next_plan,
        c.next_date
    FROM CTE1 c JOIN plans p ON c.plan_id = p.plan_id WHERE c.plan_id IN (1,2)),
payments_recursive AS (
SELECT customer_id,
        plan_id,
        price,
        payment_date,
        next_plan,
        next_date
    FROM CTE2
    UNION ALL
SELECT customer_id,
        plan_id,
        price,
        DATE_ADD(payment_date, INTERVAL 1 MONTH),
        next_plan,
        next_date
    FROM payments_recursive
    WHERE DATE_ADD(payment_date, INTERVAL 1 MONTH) < IFNULL(next_date, '2021-01-01')), 
final_payments AS 
(SELECT 
	pr.customer_id, pr.payment_date,
	CASE 
	WHEN pr.plan_id = 1 AND pr.next_plan = 2 
	AND MONTH(pr.payment_date) = MONTH(pr.next_date)
	THEN 19.90 - 9.90
	WHEN pr.plan_id = 2 AND pr.next_plan = 3 
	AND pr.payment_date = DATE_SUB(pr.next_date, INTERVAL 0 DAY)
	THEN 199
	ELSE pr.price
	END AS amount
FROM payments_recursive pr),
CTE3 AS 
(SELECT f.*
    FROM final_payments f
    LEFT JOIN subscriptions s
        ON f.customer_id = s.customer_id 
        AND s.plan_id = 4 
        AND f.payment_date >= s.start_date
    WHERE s.customer_id IS NULL)
SELECT * FROM CTE3
WHERE YEAR(payment_date) = 2020
ORDER BY customer_id, payment_date;
