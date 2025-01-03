SELECT 
    p.ProductName,
    COUNT(od.OrderDetailID) AS total_orders
FROM fact_orderdetails od
JOIN dim_products p ON od.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY total_orders DESC
LIMIT 10;

SELECT 
    s.ShipperName,
    COUNT(od.OrderDetailID) AS total_orders
FROM fact_orderdetails od
JOIN dim_shippers s ON od.ShipperID = s.ShipperID
GROUP BY s.ShipperName
ORDER BY total_orders DESC;

SELECT 
    d.year AS year,
    COUNT(od.OrderDetailID) AS total_orders
FROM fact_orderdetails od
JOIN dim_date d ON od.DateID = d.DateID
GROUP BY d.year
ORDER BY d.year;

SELECT 
    d.day AS day,
    COUNT(od.OrderDetailID) AS total_orders
FROM fact_orderdetails od
JOIN dim_date d ON od.DateID = d.DateID
GROUP BY d.day
ORDER BY total_orders DESC;

SELECT 
    c.City AS customer_city,
    COUNT(od.OrderDetailID) AS total_orders
FROM fact_orderdetails od
JOIN dim_customers c ON od.CustomerID = c.CustomerID
GROUP BY c.City
ORDER BY total_orders DESC;