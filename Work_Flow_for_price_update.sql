-----------------------------------------------------------------
-- DOCUMENTATION FOR PRICE UPLOAD WORKFLOW
-----------------------------------------------------------------

-----------------------------------------------------------------
-- Selecting the database if needed
USE alink_database;
-----------------------------------------------------------------


-- Uploading file from Soft1

-- 'Temporary' table
CREATE TABLE SOFT1_POLCAR_SHORT_TEMP (
    A_A INT,
    ERP_CODE VARCHAR(100),
    BUING_COST decimal (10, 5),
    MARKUP_ΧΟΝΔΡΙΚΗΣ decimal (10, 5),
    ΧΟΝΔΡΙΚΗΣ decimal (10, 5)
);

-- Loading into 'temporary' table
LOAD DATA LOCAL INFILE 'C:/A-LINK/Soft1_Short_Export.csv'
INTO TABLE SOFT1_POLCAR_SHORT_TEMP
CHARACTER SET UTF8
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Creating main table for Soft1 that will have data uploaded from Sof1 'temporary' table
CREATE TABLE SOFT1_POLCAR_SHORT (
    A_A INT,
    ERP_CODE VARCHAR(100) PRIMARY KEY,
    BUING_COST decimal (10, 5),
    MARKUP_ΧΟΝΔΡΙΚΗΣ decimal (10, 5),
    ΧΟΝΔΡΙΚΗΣ decimal (10, 5)
);

-- Loading data from 'temporary' Soft1 table into main one
INSERT IGNORE INTO SOFT1_POLCAR_SHORT
SELECT * FROM SOFT1_POLCAR_SHORT_TEMP;

# Check if the data is loaded
select *
from soft1_polcar_short;

---------------------------------------

-- Creating 'Temporary' table for Polcar original (fixed) file upload
CREATE TABLE POLCAR_PRODUCTS_TEMP (
    NumerPOLCAR VARCHAR(100),
    NazwaGrupy VARCHAR(80),
    NazwaRodzaju VARCHAR(100),
    NazwaCzesci VARCHAR(150),
    Zastosowanie VARCHAR(70),
    NazwaNaFakture VARCHAR(150),
    NazwaJakosci VARCHAR(20),
    OE text,
    Ilosc INT,
    Magazyn INT,
    CenaKlienta DECIMAL (10, 5),
    Dostawa VARCHAR(50),
    Producent VARCHAR(80),
    EAN13 VARCHAR(30),
    WagaBrutto INT,
    NazwaStanuTowaru VARCHAR(60),
    DataGeneracjiRaportu VARCHAR(20),
    NumerProducenta TEXT,
    NumerKType TEXT,
    PCN VARCHAR(50),
    GTU VARCHAR(50),
    Jakosc VARCHAR(20),
    Jednostka VARCHAR(30),
    CenaKlienta1pc DECIMAL(10, 5)
);

-- Load polcar fixed file into 'temporary' table:
LOAD DATA LOCAL INFILE 'C:/A-LINK/polcar_fixed.csv'
INTO TABLE polcar_products_temp
CHARACTER SET UTF8
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Identify and delete duplicates, keeping only one instance of each duplicate set
ALTER TABLE POLCAR_PRODUCTS_TEMP
ADD COLUMN rowID INT AUTO_INCREMENT PRIMARY KEY FIRST;

DELETE t1
FROM POLCAR_PRODUCTS_TEMP t1
INNER JOIN (
    SELECT NumerPOLCAR, MIN(rowID) as minID
    FROM POLCAR_PRODUCTS_TEMP
    GROUP BY NumerPOLCAR
    HAVING COUNT(*) > 1
) t2
ON t1.NumerPOLCAR = t2.NumerPOLCAR
WHERE t1.rowID > t2.minID;

-- After we deleted the duplicates, we dont need the col 'rowID', so we delete it
ALTER TABLE POLCAR_PRODUCTS_TEMP
DROP COLUMN rowID;

-- Set correct Date and Time (so far its a string, we need to convert it to datetime variable)
SET sql_mode = '';

UPDATE POLCAR_PRODUCTS_TEMP
SET DataGeneracjiRaportu = NULL
WHERE DataGeneracjiRaportu = '0000-00-00 00:00:00';

-- Creating a main Polcar (fixed) table with extra dynamic column that will be our primary key (99+NumerPOLCAR - Soft1 code)
CREATE TABLE POLCAR_PRODUCTS (
    NumerPOLCAR VARCHAR(100),
    NazwaGrupy VARCHAR(80),
    NazwaRodzaju VARCHAR(100),
    NazwaCzesci VARCHAR(150),
    Zastosowanie VARCHAR(70),
    NazwaNaFakture VARCHAR(150),
    NazwaJakosci VARCHAR(20),
    OE text,
    Ilosc INT,
    Magazyn INT,
    CenaKlienta DECIMAL (10, 5),
    Dostawa VARCHAR(50),
    Producent VARCHAR(80),
    EAN13 VARCHAR(30),
    WagaBrutto INT,
    NazwaStanuTowaru VARCHAR(60),
    DataGeneracjiRaportu DATETIME,
    NumerProducenta TEXT,
    NumerKType TEXT,
    PCN VARCHAR(50),
    GTU VARCHAR(50),
    Jakosc VARCHAR(20),
    Jednostka VARCHAR(30),
    CenaKlienta1pc DECIMAL(10, 5),
    ERP_CODE VARCHAR(100) GENERATED ALWAYS AS (CONCAT('99', NumerPOLCAR)) STORED,
    PRIMARY KEY (ERP_CODE)
);

-- Inserting our data from Polcar (fixed) into main table with ERP CODE:
INSERT INTO POLCAR_PRODUCTS (NumerPOLCAR, NazwaGrupy, NazwaRodzaju, NazwaCzesci, Zastosowanie, NazwaNaFakture,
                             NazwaJakosci, OE, Ilosc, Magazyn, CenaKlienta, Dostawa, Producent, EAN13, WagaBrutto,
                             NazwaStanuTowaru, DataGeneracjiRaportu, NumerProducenta, NumerKType, PCN, GTU, Jakosc,
                             Jednostka, CenaKlienta1pc)
SELECT NumerPOLCAR, NazwaGrupy, NazwaRodzaju, NazwaCzesci, Zastosowanie, NazwaNaFakture, NazwaJakosci, OE, Ilosc,
       Magazyn, CenaKlienta, Dostawa, Producent, EAN13, WagaBrutto, NazwaStanuTowaru, DataGeneracjiRaportu,
       NumerProducenta, NumerKType, PCN, GTU, Jakosc, Jednostka, CenaKlienta1pc
FROM POLCAR_PRODUCTS_TEMP;

-- Check if data is loaded
select *
from polcar_products;


---------------------------------------
-- Explore the data from both tables

-- See the change in prices (change between <>, <, > to see the number of new prices and how they change)
SELECT
    p.ERP_CODE,
    p.CenaKlienta AS Price_Polcar,
    s.BUING_COST AS Price_Soft1
FROM
    polcar_products p
JOIN
    soft1_polcar_short s ON p.ERP_CODE = s.ERP_CODE
WHERE
    p.CenaKlienta > s.BUING_COST;

-- See the number of products that are not in Soft1 but are in the original file (possibly new products)
SELECT COUNT(*) AS MissingKeysCount
FROM POLCAR_PRODUCTS
WHERE polcar_products.ERP_CODE NOT IN (SELECT ERP_CODE FROM soft1_polcar_short);

-- Detailed view on possibly new products
SELECT *
FROM POLCAR_PRODUCTS
WHERE polcar_products.ERP_CODE NOT IN (SELECT ERP_CODE FROM soft1_polcar_short);

---------------------------------------

-- Creating temporary table for the final, upload table
CREATE TEMPORARY TABLE temp_new_prices_table (
    ERP_CODE VARCHAR(100),
    BUING_COST DECIMAL(10, 5),
    MARKUP_ΧΟΝΔΡΙΚΗΣ DECIMAL(10, 5),
    ΧΟΝΔΡΙΚΗΣ DECIMAL(10, 5)
);
-- Insert the first 7 rows with NULL values as file for upload should start from 8th row
INSERT INTO temp_new_prices_table (ERP_CODE, BUING_COST, MARKUP_ΧΟΝΔΡΙΚΗΣ, ΧΟΝΔΡΙΚΗΣ)
VALUES
    (NULL, NULL, NULL, NULL),
    (NULL, NULL, NULL, NULL),
    (NULL, NULL, NULL, NULL),
    (NULL, NULL, NULL, NULL),
    (NULL, NULL, NULL, NULL),
    (NULL, NULL, NULL, NULL);

-- Insert data from Polcar table and Soft1 table into the temporary upload table (choose between <>, <, > to export only where the prices are different)
INSERT INTO temp_new_prices_table (ERP_CODE, BUING_COST, MARKUP_ΧΟΝΔΡΙΚΗΣ, ΧΟΝΔΡΙΚΗΣ)
SELECT
    p.ERP_CODE,
    p.CenaKlienta AS BUING_COST,
    17.64 AS MARKUP_ΧΟΝΔΡΙΚΗΣ,
    ΧΟΝΔΡΙΚΗΣ
FROM
    polcar_products p
JOIN
    soft1_polcar_short s ON p.ERP_CODE = s.ERP_CODE
WHERE
    p.CenaKlienta > s.BUING_COST;

-- Calculating and updating the column with prices ΧΟΝΔΡΙΚΗΣ

UPDATE temp_new_prices_table
SET ΧΟΝΔΡΙΚΗΣ = BUING_COST + (BUING_COST * MARKUP_ΧΟΝΔΡΙΚΗΣ / 100);

-- Check the temporary upload table
select *
from temp_new_prices_table;


---------------------------------------
---------------------------------------

-- Delete created tables after you export the file, so it will not be confused next day with the old
DROP TABLE SOFT1_POLCAR_SHORT_TEMP;
DROP TABLE SOFT1_POLCAR_SHORT;
DROP TABLE POLCAR_PRODUCTS_TEMP;

-- This table might be useful for new product upload. If there are no new products to upload, delete it too
DROP TABLE POLCAR_PRODUCTS;

---------------------------------------
-- THE END
---------------------------------------
