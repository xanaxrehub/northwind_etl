CREATE DATABASE SPIDER_NorthWind_DB;

CREATE SCHEMA SPIDER_NorthWind_DB.staging;

USE SCHEMA SPIDER_NorthWind_DB.staging;

CREATE TABLE categories_staging (
    CategoryId INT PRIMARY KEY,
    CategoryName VARCHAR(25),
    Description VARCHAR(255)
);

CREATE TABLE suppliers_staging (
    SupplierId INT PRIMARY KEY,
    SupplierName VARCHAR(50),
    ContactName VARCHAR(50),
    Address VARCHAR(50),
    City VARCHAR(20),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(15)
);

CREATE TABLE products_staging (
    ProductId INT PRIMARY KEY,
    ProductName VARCHAR(50),
    SupplierID INT,
    CategoryID INT,
    FOREIGN KEY (SupplierID) REFERENCES suppliers_staging(SupplierID),
    FOREIGN KEY (CategoryID) REFERENCES categories_staging(CategoryID),
    Unit VARCHAR(25),
    PRICE DECIMAL(10,0)
);

CREATE TABLE employees_staging (
    EmployeeID INT PRIMARY KEY,
    LastName VARCHAR(15),
    FirstName VARCHAR(15),
    BirthDate DATETIME,
    Photo VARCHAR(25),
    Notes VARCHAR(1024)
);

CREATE TABLE customers_staging (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(50),
    ContactName VARCHAR(50),
    Address VARCHAR(50),
    City VARCHAR(20),
    PostalCode VARCHAR(10),
    Country VARCHAR(15)
);

CREATE TABLE shippers_staging (
    ShipperID INT PRIMARY KEY,
    ShipperName VARCHAR(25),
    Phone VARCHAR(15)
);

CREATE TABLE orders_staging (
    OrderID INT PRIMARY KEY,
    CustomerID INT,
    EmployeeID INT,
    OrderDate DATETIME,
    ShipperID INT,
    FOREIGN KEY (CustomerID) REFERENCES
    customers_staging(CustomerID),
    FOREIGN KEY (EmployeeID) REFERENCES
    employees_staging(EmployeeID),
    FOREIGN KEY (ShipperID) REFERENCES
    shippers_staging(ShipperID)
);

CREATE TABLE orderdetails_staging (
    OrderDetailID INT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    FOREIGN KEY (OrderID) REFERENCES
    orders_staging(OrderID),
    FOREIGN KEY (ProductID) REFERENCES
    products_staging(ProductID)
);

CREATE OR REPLACE STAGE my_stage;

COPY INTO categories_staging
FROM @my_stage/categories.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO suppliers_staging
FROM @my_stage/suppliers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO products_staging
FROM @my_stage/products.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO employees_staging
FROM @my_stage/employees.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO customers_staging
FROM @my_stage/customers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO shippers_staging
FROM @my_stage/shippers.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO orders_staging
FROM @my_stage/orders.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO orderdetails_staging
FROM @my_stage/orderdetails.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

CREATE TABLE dim_products AS
SELECT DISTINCT
    p.ProductID,
    p.ProductName,
    c.CategoryName AS ProductCategory,
    s.SupplierName,
    s.Country,
    s.City
FROM products_staging p
JOIN categories_staging c ON p.CategoryID = c.CategoryID
JOIN suppliers_staging s ON p.SupplierID = s.SupplierID;

CREATE TABLE dim_shippers AS
SELECT DISTINCT
    s.ShipperID,
    s.ShipperName
FROM shippers_staging s;

CREATE TABLE dim_customers AS
SELECT DISTINCT
    c.CustomerID,
    c.CustomerName,
    c.City,
    c.Country,
FROM customers_staging c;

CREATE TABLE dim_employees AS
SELECT DISTINCT
    e.EmployeeID,
    e.FirstName as First_Name,
    e.LastName as Last_Name,
    YEAR(e.BirthDate) as Birth_Year,
FROM employees_staging e;

CREATE TABLE dim_date AS
SELECT DISTINCT
    ROW_NUMBER() OVER (ORDER BY CAST(OrderDate AS DATE)) AS DateID,
    CAST(OrderDate AS DATE) AS date,
    DATE_PART(year, OrderDate) AS year,
    DATE_PART(month, OrderDate) AS month,
    DATE_PART(day, OrderDate) AS day,
FROM orders_staging
GROUP BY CAST(OrderDate AS DATE), 
         DATE_PART(day, OrderDate),
         DATE_PART(month, OrderDate), 
         DATE_PART(year, OrderDate);

CREATE TABLE fact_orderdetails AS
SELECT 
    od.OrderDetailID,
    ps.Price AS ProductPrice,
    od.Quantity AS ProductQuantity,
    p.ProductID, 
    e.EmployeeID, 
    c.CustomerID, 
    s.ShipperID, 
    d.DateID,
    od.OrderID
FROM orderdetails_staging od JOIN orders_staging o ON od.OrderID = o.OrderID
JOIN products_staging ps ON od.ProductID = ps.ProductID
JOIN dim_products p ON od.ProductID = p.ProductID
JOIN dim_employees e ON o.EmployeeID = e.EmployeeID
JOIN dim_customers c ON o.CustomerID = c.CustomerID
JOIN dim_shippers s ON o.ShipperID = s.ShipperID
JOIN dim_date d ON CAST(o.OrderDate as DATE) = d.date;

DROP TABLE IF EXISTS categories_staging;
DROP TABLE IF EXISTS products_staging;
DROP TABLE IF EXISTS suppliers_staging;
DROP TABLE IF EXISTS shippers_staging;
DROP TABLE IF EXISTS orders_staging;
DROP TABLE IF EXISTS customers_staging;
DROP TABLE IF EXISTS employees_staging;
DROP TABLE IF EXISTS orderdetails_staging;