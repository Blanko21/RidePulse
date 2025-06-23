-- 1. Total number of customers
SELECT COUNT(*) AS total_customers FROM customers;

-- 2. Total number of drivers
SELECT COUNT(*) AS total_drivers FROM drivers;

-- 3. Number of trips in the last 30 days
SELECT COUNT(*) AS trips_last_30_days
FROM trips
WHERE trip_start >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

-- 4. Most popular city for trips
SELECT city, COUNT(*) AS trip_count
FROM trips
GROUP BY city
ORDER BY trip_count DESC
LIMIT 1;

-- 5. Average trip distance by city
SELECT city, AVG(distance_km) AS avg_distance
FROM trips
GROUP BY city
ORDER BY avg_distance DESC;

-- 6. Payment method distribution
SELECT payment_method, COUNT(*) AS num_trips
FROM trips
GROUP BY payment_method
ORDER BY num_trips DESC;

-- 7. Average customer age by loyalty tier
SELECT loyalty_tier, AVG(age) AS avg_age
FROM customers
GROUP BY loyalty_tier;

-- 8. Driver with the highest total trips
SELECT name2, total_trips
FROM drivers
ORDER BY total_trips DESC
LIMIT 1;

-- 9. Top 5 drivers by earnings in the last week (from driver_logs)
SELECT d.name2, SUM(dl.earnings) AS total_earnings
FROM driver_logs dl
JOIN drivers d ON dl.driver_id = d.id
WHERE dl.log_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
GROUP BY dl.driver_id, d.name2
ORDER BY total_earnings DESC
LIMIT 5;

-- 10. Number of completed, cancelled, and no-show trips
SELECT status1, COUNT(*) AS count
FROM trips
GROUP BY status1;

-- 11. Average trip rating
SELECT AVG(rating) AS avg_rating FROM feedback;

-- 12. Trips with complaints (issue_flagged not 'No')
SELECT COUNT(*) AS complaint_trips
FROM feedback
WHERE issue_flagged <> 'No';

-- 13. Percentage of failed or pending payments
SELECT
  ROUND(100.0 * SUM(CASE WHEN payment_status <> 'Success' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_failed_pending
FROM payments;

-- 14. Customers with most trips
SELECT c.name1, COUNT(*) AS num_trips
FROM trips t
JOIN customers c ON t.customer_id = c.id
GROUP BY t.customer_id, c.name1
ORDER BY num_trips DESC
LIMIT 5;

-- 15. Average waiting time per city
SELECT city, AVG(wait_time_min) AS avg_wait
FROM trips
GROUP BY city
ORDER BY avg_wait DESC;

-- 16. Surge multiplier impact: avg fare by surge level
SELECT surge_multiplier, AVG(p.amount) AS avg_fare
FROM trips t
JOIN payments p ON t.id = p.trip_id
GROUP BY surge_multiplier
ORDER BY surge_multiplier DESC;

-- 17. Distribution of ratings (feedback)
SELECT rating, COUNT(*) AS count
FROM feedback
GROUP BY rating
ORDER BY rating DESC;

-- 18. Loyalty tier distribution among customers
SELECT loyalty_tier, COUNT(*) AS num_customers
FROM customers
GROUP BY loyalty_tier;

-- 19. Gender distribution among drivers and customers
SELECT 'Driver' AS user_type, gender, COUNT(*) AS count FROM drivers GROUP BY gender
UNION ALL
SELECT 'Customer', gender, COUNT(*) FROM customers GROUP BY gender;

-- 20. Average number of trips per driver per day (last 7 days)
SELECT AVG(total_trips) AS avg_trips_per_day
FROM driver_logs
WHERE log_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);

-- 21. For each customer, show their latest trip date and previous trip date
SELECT
  c.name1 AS customer_name,
  t.trip_start AS current_trip_start,
  LAG(t.trip_start, 1) OVER (PARTITION BY t.customer_id ORDER BY t.trip_start) AS previous_trip_start
FROM trips t
JOIN customers c ON t.customer_id = c.id
ORDER BY c.name1, t.trip_start DESC;

-- 22. For each driver, calculate the difference in earnings between consecutive days
SELECT
  d.name2 AS driver_name,
  dl.log_date,
  dl.earnings,
  LAG(dl.earnings) OVER (PARTITION BY dl.driver_id ORDER BY dl.log_date) AS prev_day_earnings,
  dl.earnings - LAG(dl.earnings) OVER (PARTITION BY dl.driver_id ORDER BY dl.log_date) AS earnings_diff
FROM driver_logs dl
JOIN drivers d ON dl.driver_id = d.id
ORDER BY d.name2, dl.log_date DESC;

-- 23. Find customers whose latest trip received a rating less than 3
WITH latest_trip AS (
  SELECT
    t.customer_id,
    MAX(t.trip_start) AS latest_trip_start
  FROM trips t
  GROUP BY t.customer_id
)
SELECT
  c.name1,
  t.trip_start,
  f.rating
FROM latest_trip lt
JOIN trips t ON lt.customer_id = t.customer_id AND lt.latest_trip_start = t.trip_start
JOIN feedback f ON t.id = f.trip_id
JOIN customers c ON t.customer_id = c.id
WHERE f.rating < 3;

-- 24. For each city, show the top 3 drivers by total trips completed in that city
WITH driver_city_trips AS (
  SELECT
    t.driver_id,
    d.name2 AS driver_name,
    t.city,
    COUNT(*) AS trips_in_city
  FROM trips t
  JOIN drivers d ON t.driver_id = d.id
  WHERE t.status1 = 'completed'
  GROUP BY t.driver_id, d.name2, t.city
),
ranked AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY city ORDER BY trips_in_city DESC) AS city_rank
  FROM driver_city_trips
)
SELECT city, driver_name, trips_in_city
FROM ranked
WHERE city_rank <= 3
ORDER BY city, city_rank;

-- 25. For each trip, show payment amount, trip distance, and the average payment for all trips with similar surge_multiplier
SELECT
  t.id AS trip_id,
  t.surge_multiplier,
  t.distance_km,
  p.amount,
  AVG(p.amount) OVER (PARTITION BY t.surge_multiplier) AS avg_amount_for_surge
FROM trips t
JOIN payments p ON t.id = p.trip_id
ORDER BY t.surge_multiplier, t.id;

-- 26. Find the top 5 customers who most often flagged an issue in feedback
SELECT
  c.name1,
  COUNT(*) AS flagged_issues
FROM feedback f
JOIN customers c ON f.customer_id = c.id
WHERE f.issue_flagged <> 'No'
GROUP BY c.name1
ORDER BY flagged_issues DESC
LIMIT 5;

-- 27. For each driver, show total earnings and their rank among all drivers
SELECT
  d.name2,
  SUM(dl.earnings) AS total_earnings,
  RANK() OVER (ORDER BY SUM(dl.earnings) DESC) AS earnings_rank
FROM driver_logs dl
JOIN drivers d ON dl.driver_id = d.id
GROUP BY d.name2
ORDER BY earnings_rank;

-- 28. Show all trips where the payment status was not 'Success' and the customer had more than 5 trips in total
SELECT
  t.id AS trip_id,
  c.name1 AS customer_name,
  p.amount,
  p.payment_status,
  t.trip_start
FROM payments p
JOIN trips t ON p.trip_id = t.id
JOIN customers c ON p.customer_id = c.id
WHERE p.payment_status <> 'Success'
  AND c.id IN (
    SELECT customer_id
    FROM trips
    GROUP BY customer_id
    HAVING COUNT(*) > 5
  )
ORDER BY c.name1, t.trip_start DESC;

-- 29. Find drivers who had zero trips on any day within the last week
SELECT d.name2, dl.log_date
FROM driver_logs dl
JOIN drivers d ON dl.driver_id = d.id
WHERE dl.log_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
  AND dl.total_trips = 0;

-- 30. For each city, calculate the average trip rating and the number of unique drivers
SELECT
  t.city,
  AVG(f.rating) AS avg_rating,
  COUNT(DISTINCT t.driver_id) AS unique_drivers
FROM trips t
JOIN feedback f ON t.id = f.trip_id
GROUP BY t.city
ORDER BY avg_rating DESC;

-- 31. For each customer, show the number of days between their last and second last trip
SELECT
  c.name1,
  t.trip_start AS last_trip,
  LAG(t.trip_start) OVER (PARTITION BY t.customer_id ORDER BY t.trip_start DESC) AS previous_trip,
  DATEDIFF(t.trip_start, LAG(t.trip_start) OVER (PARTITION BY t.customer_id ORDER BY t.trip_start DESC)) AS days_between
FROM trips t
JOIN customers c ON t.customer_id = c.id
ORDER BY c.name1, t.trip_start DESC;

-- 32. Find the average time drivers spend online per trip
SELECT
  d.name2,
  SUM(dl.hours_online) / NULLIF(SUM(dl.total_trips),0) AS avg_hours_per_trip
FROM driver_logs dl
JOIN drivers d ON dl.driver_id = d.id
GROUP BY d.name2
ORDER BY avg_hours_per_trip DESC
LIMIT 10;

-- 33. For each driver, find their longest streak of days with at least one trip
WITH streaks AS (
  SELECT
    dl.driver_id,
    dl.log_date,
    dl.total_trips,
    CASE WHEN dl.total_trips > 0 THEN 1 ELSE 0 END AS trip_day,
    ROW_NUMBER() OVER (PARTITION BY dl.driver_id ORDER BY dl.log_date) -
      SUM(CASE WHEN dl.total_trips > 0 THEN 1 ELSE 0 END) OVER (PARTITION BY dl.driver_id ORDER BY dl.log_date) AS grp
  FROM driver_logs dl
)
SELECT
  d.name2,
  MAX(streak_length) AS max_streak
FROM (
  SELECT
    s.driver_id,
    COUNT(*) AS streak_length
  FROM streaks s
  WHERE s.trip_day = 1
  GROUP BY s.driver_id, s.grp
) AS streak_summary
JOIN drivers d ON streak_summary.driver_id = d.id
GROUP BY d.name2
ORDER BY max_streak DESC
LIMIT 10;

-- 34. List all trips where the actual trip distance was more than 2x the average for that route (city+start+end)
WITH avg_route_distance AS (
  SELECT city, start_location, end_location, AVG(distance_km) AS avg_distance
  FROM trips
  GROUP BY city, start_location, end_location
)
SELECT
  t.id AS trip_id,
  t.city,
  t.start_location,
  t.end_location,
  t.distance_km,
  a.avg_distance
FROM trips t
JOIN avg_route_distance a
  ON t.city = a.city
  AND t.start_location = a.start_location
  AND t.end_location = a.end_location
WHERE t.distance_km > 2 * a.avg_distance
ORDER BY t.city, t.start_location, t.end_location;

-- 35. Find drivers who received below-average ratings more than 3 times in the past month
WITH avg_rating AS (
  SELECT AVG(rating) AS avg_rating FROM feedback
), bad_ratings AS (
  SELECT
    f.driver_id,
    COUNT(*) AS bad_rating_count
  FROM feedback f
  JOIN trips t ON f.trip_id = t.id
  WHERE f.rating < (SELECT avg_rating FROM avg_rating)
    AND t.trip_start >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  GROUP BY f.driver_id
)
SELECT d.name2, bad_rating_count
FROM bad_ratings br
JOIN drivers d ON br.driver_id = d.id
WHERE bad_rating_count > 3
ORDER BY bad_rating_count DESC;