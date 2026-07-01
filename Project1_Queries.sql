USE mydb;


-- Q1: Vendor spend vs asset health
--     Which vendors are we spending the most with,
--     and how many of their assets are active vs problematic?
SELECT 
	v.vendor_name, 
	v.category, 
	COUNT(a.asset_id) AS total_assets, 
	SUM(a.purchase_price) AS total_spent, 
	SUM(CASE WHEN a.status = 'Active' THEN 1 ELSE 0 END) AS active_assets, 
	SUM(CASE WHEN a.status !='Active' THEN 1 ELSE 0 END) AS problem_assets, 
	ROUND(SUM(CASE WHEN a.status != 'Active' THEN 1 ELSE 0 END) / COUNT(a.asset_id) * 100, 1) AS problem_rate_pct
FROM vendors v
JOIN assets a ON v.vendor_id = a.vendor_id
GROUP BY v.vendor_id, v.vendor_name, v.category
ORDER BY total_spent DESC;



-- Q2: Software license utilization — identify waste
--     Which licenses are underutilized (below 80% usage)?
SELECT
    sl.software_name,
    v.vendor_name,
    sl.license_type,
    sl.seats_purchased,
    sl.seats_used,
    sl.seats_purchased - sl.seats_used AS unused_seats,
    ROUND(sl.seats_used / sl.seats_purchased * 100, 1) AS utilization_pct,
    sl.annual_cost,
    ROUND(sl.annual_cost / sl.seats_purchased, 2) AS cost_per_seat,
    CASE
        WHEN sl.seats_used / sl.seats_purchased < 0.80 THEN 'Underutilized — Review'
        ELSE 'Healthy'
    END AS utilization_flag
FROM software_licenses sl
JOIN vendors v ON sl.vendor_id = v.vendor_id
ORDER BY utilization_pct ASC;



-- Q3: Total asset value by category
--     How much have we spent on laptops vs servers vs networking?
SELECT
    ac.category_name,
    COUNT(a.asset_id) AS total_assets,
    SUM(a.purchase_price) AS total_value,
    ROUND(AVG(a.purchase_price), 2) AS avg_unit_price,
    MIN(a.purchase_price) AS min_price,
    MAX(a.purchase_price) AS max_price
FROM asset_categories ac
JOIN assets a ON ac.category_id = a.category_id
GROUP BY ac.category_id, ac.category_name
ORDER BY total_value DESC;




-- Q4: Assets coming off warranty within the next year
--     What do we need to budget to replace or extend coverage on?
SELECT
    a.asset_id,
    a.asset_name,
    ac.category_name,
    v.vendor_name,
    CONCAT(e.first_name, ' ', e.last_name) AS assigned_to,
    d.department_name,
    a.warranty_expiry,
    DATEDIFF(a.warranty_expiry, CURDATE()) AS days_until_expiry,
    a.purchase_price
FROM assets a
JOIN asset_categories ac ON a.category_id = ac.category_id
JOIN vendors v ON a.vendor_id   = v.vendor_id
LEFT JOIN employees e ON a.assigned_to = e.employee_id
LEFT JOIN departments d ON e.department_id = d.department_id
WHERE a.warranty_expiry BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 1 YEAR)
  AND a.status = 'Active'
ORDER BY a.warranty_expiry ASC;



-- Q5: Employees with more than one asset assigned
--     Useful for auditing asset distribution
SELECT
    CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
    e.job_title,
    d.department_name,
    COUNT(a.asset_id) AS assets_assigned,
    SUM(a.purchase_price) AS total_asset_value,
    GROUP_CONCAT(a.asset_name SEPARATOR ', ') AS assets
FROM employees e
JOIN assets a ON e.employee_id   = a.assigned_to
JOIN departments d ON e.department_id = d.department_id
GROUP BY e.employee_id, e.first_name, e.last_name, e.job_title, d.department_name
HAVING COUNT(a.asset_id) > 1
ORDER BY assets_assigned DESC;



-- Q6: IT technician workload and resolution time
--     Who has the highest workload and fastest resolution time?
SELECT
    CONCAT(e.first_name, ' ', e.last_name) AS technician,
    e.job_title,
    COUNT(t.ticket_id) AS total_tickets,
    SUM(CASE WHEN t.status = 'Closed' THEN 1 ELSE 0 END) AS tickets_closed,
    SUM(CASE WHEN t.status = 'Open'   THEN 1 ELSE 0 END) AS tickets_open,
    ROUND(AVG(DATEDIFF(t.date_closed, t.date_opened)), 1) AS avg_resolution_days
FROM employees e
JOIN tickets t ON e.employee_id = t.assigned_to
GROUP BY e.employee_id, e.first_name, e.last_name, e.job_title
ORDER BY total_tickets DESC;



-- Q7: Tickets submitted by department
--     Which department has the most IT problems?
SELECT
    d.department_name,
    COUNT(t.ticket_id) AS total_tickets,
    SUM(CASE WHEN t.priority = 'Critical' THEN 1 ELSE 0 END) AS critical,
    SUM(CASE WHEN t.priority = 'High'     THEN 1 ELSE 0 END) AS high,
    SUM(CASE WHEN t.priority = 'Medium'   THEN 1 ELSE 0 END) AS medium,
    SUM(CASE WHEN t.priority = 'Low'      THEN 1 ELSE 0 END) AS low,
    SUM(CASE WHEN t.status   = 'Open'     THEN 1 ELSE 0 END) AS still_open
FROM tickets t
JOIN employees e   ON t.submitted_by   = e.employee_id
JOIN departments d ON e.department_id  = d.department_id
GROUP BY d.department_id, d.department_name
ORDER BY total_tickets DESC;



-- Q8: IT asset count and value by department
--     Which department has the most assets assigned to its employees?
SELECT
    d.department_name,
    COUNT(a.asset_id) AS total_assets,
    SUM(a.purchase_price) AS total_asset_value,
    ROUND(AVG(a.purchase_price), 2) AS avg_asset_value
FROM departments d
JOIN employees e ON d.department_id = e.department_id
JOIN assets a ON e.employee_id   = a.assigned_to
GROUP BY d.department_id, d.department_name
ORDER BY total_assets DESC;



