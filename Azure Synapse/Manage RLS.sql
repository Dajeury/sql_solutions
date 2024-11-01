-- In the master database, create login credentials for three users: Manager, Sales1, and Sales2.
CREATE LOGIN Manager WITH PASSWORD = '[your_password_here]'
GO

CREATE LOGIN Sales1 WITH PASSWORD = '[your_password_here]'
GO

CREATE LOGIN Sales2 WITH PASSWORD = '[your_password_here]'
GO

-- Create user accounts that associate the logins with SQL Server users.
CREATE USER Manager FOR LOGIN Manager;
CREATE USER Sales1 FOR LOGIN Sales1;
CREATE USER Sales2 FOR LOGIN Sales2;
GO

------------------

-- Run this part in both the master database and the dedicated SQL pool database.
-- Create a table named 'Sales' with columns for order details.
CREATE TABLE Sales  
    (  
    OrderID int,         -- Unique identifier for each order.
    SalesRep sysname,    -- The salesperson responsible for the order.
    Product varchar(10), -- The product ordered.
    Qty int              -- Quantity of the product ordered.
    );

-----------------

-- Insert sample data into the Sales table for testing purposes.
INSERT INTO Sales VALUES (1, 'Sales1', 'Valve', 5);
INSERT INTO Sales VALUES (2, 'Sales1', 'Wheel', 2);
INSERT INTO Sales VALUES (3, 'Sales1', 'Valve', 4);
INSERT INTO Sales VALUES (4, 'Sales2', 'Bracket', 2);
INSERT INTO Sales VALUES (5, 'Sales2', 'Wheel', 5);
INSERT INTO Sales VALUES (6, 'Sales2', 'Seat', 5);

-- Display the six rows of data in the Sales table.
SELECT * FROM Sales;

-- Create an encryption key for securing the data in the database.
CREATE MASTER KEY ENCRYPTION BY PASSWORD = '[your_password_here]';

-- Define a credential using Managed Service Identity (MSI) for external data access.
CREATE DATABASE SCOPED CREDENTIAL msi_cred WITH IDENTITY = 'Managed Service Identity';

-- Define an external data source pointing to a specific container in Azure Data Lake Storage Gen2.
CREATE EXTERNAL DATA SOURCE ext_datasource_with_abfss 
    WITH (
        TYPE = hadoop,
        LOCATION = 'abfss://[file_container]@[storage_account].dfs.core.windows.net/file/', -- Specify the container and storage account URL.
        CREDENTIAL = msi_cred)
;

-- Create an external file format for reading delimited text files.
CREATE EXTERNAL FILE FORMAT MSIFormat WITH (FORMAT_TYPE=DELIMITEDTEXT);

-- Create an external table 'Sales_ext' that references data in the external storage.
-- The table reads from the 'test_sales_table' path and rejects rows that don't meet format requirements.
CREATE EXTERNAL TABLE Sales_ext 
WITH (
    LOCATION='test_sales_table', 
    DATA_SOURCE=ext_datasource_with_abfss, 
    FILE_FORMAT=MSIFormat, 
    REJECT_TYPE=Percentage, 
    REJECT_SAMPLE_VALUE=100, 
    REJECT_VALUE=100)
AS SELECT * FROM sales;

-- Grant SELECT access on the external table 'Sales_ext' to the Manager, Sales1, and Sales2 users.
GRANT SELECT ON Sales_ext TO Manager;
GRANT SELECT ON Sales_ext TO Sales1;
GRANT SELECT ON Sales_ext TO Sales2;
GO

-- Create a new schema named 'Security' to organize security-related objects.
CREATE SCHEMA Security;
GO;

-- Define a security function to filter rows based on the salesperson's name.
-- The function allows access if the row's SalesRep matches the logged-in user or if the user is 'Manager'.
CREATE FUNCTION Security.fn_securitypredicate(@SalesRep AS sysname)
    RETURNS TABLE
    WITH SCHEMABINDING
    AS
    RETURN
    SELECT 1 AS fn_securitypredicate_result
    WHERE @SalesRep = USER_NAME() OR USER_NAME() = 'Manager';
GO

-- Create a security policy named 'SalesFilter_ext' that applies the filter function.
-- The policy ensures that users only see rows where they are the SalesRep or if they are the Manager.
CREATE SECURITY POLICY SalesFilter_ext
ADD FILTER PREDICATE Security.fn_securitypredicate(SalesRep)
ON dbo.Sales_ext  
WITH (STATE = ON);
GO

-- Query the external table 'Sales_ext' to view the filtered results.
SELECT * FROM dbo.Sales_ext
GO

-- Test the security policy by impersonating the 'Sales1' user.
EXECUTE AS USER = 'Sales1';
SELECT * FROM dbo.Sales_ext;
REVERT; -- Return to the original user.
