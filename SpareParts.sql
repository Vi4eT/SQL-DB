--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'SparePartsDB'
GO
USE [master]
GO
ALTER DATABASE [SparePartsDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [SparePartsDB]
GO

-- 13 --
--Create DB
CREATE DATABASE [SparePartsDB]
GO

USE [SparePartsDB]
GO

CREATE TABLE [ProviderType](
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(20) UNIQUE NOT NULL
) 
GO

INSERT INTO ProviderType ([Name]) VALUES 
	('Фирма'), 
	('Дилер'), 
	('Производство'),
	('Мелкий поставщик'), 
	('Магазин')
GO

CREATE TABLE [Provider](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) UNIQUE NOT NULL,
	[TypeID] tinyint NOT NULL REFERENCES [ProviderType] (ID)
) 
GO

CREATE TABLE [Part](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) UNIQUE NOT NULL
) 
GO

CREATE TABLE [PriceList](
	[ID] int PRIMARY KEY IDENTITY,
	[ProviderID] int NOT NULL REFERENCES [Provider] (ID),
	[PartID] int NOT NULL REFERENCES [Part] (ID),
	[Price] money NOT NULL,
	[DeliveryIn] tinyint NOT NULL
) 
GO

--заказы поставщикам
CREATE TABLE [Order](
	[ID] int PRIMARY KEY IDENTITY,
	[ProviderID] int NOT NULL REFERENCES [Provider] (ID),
	[PartID] int NOT NULL REFERENCES Part (ID),
	[Quantity] int NOT NULL CONSTRAINT CK_Order_Quantity CHECK (Quantity > 0)
) 
GO

CREATE TABLE [Buyer](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) UNIQUE NOT NULL
) 
GO

--заявки покупателей
CREATE TABLE [Request](
	[ID] int PRIMARY KEY IDENTITY,
	[BuyerID] int NOT NULL REFERENCES Buyer (ID),
	[PartID] int NOT NULL REFERENCES Part (ID),
	[Quantity] int NOT NULL CONSTRAINT CK_Request_Quantity CHECK (Quantity > 0),
	[Price] money NOT NULL CONSTRAINT CK_Request_Price CHECK (Price > 0)
) 
GO

CREATE TABLE [Sale](
	[ID] int PRIMARY KEY IDENTITY,
	[BuyerID] int NOT NULL REFERENCES Buyer (ID),
	[PartID] int NOT NULL REFERENCES Part (ID),
	[Quantity] int NOT NULL CONSTRAINT CK_Sale_Quantity CHECK (Quantity > 0),
	[Price] money NOT NULL CONSTRAINT CK_Sale_Price CHECK (Price > 0),
	[Date] date NOT NULL
) 
GO

CREATE TABLE [Storage](
	[ID] int PRIMARY KEY IDENTITY,
	[Cell] int NOT NULL CONSTRAINT CK_Storage_Cell_Numbers CHECK (Cell > 0 AND Cell <= 10000),
	[PartID] int NOT NULL REFERENCES Part (ID),
	[Quantity] int NOT NULL CONSTRAINT CK_Storage_Quantity CHECK (Quantity >= 0),
	[Purchase Price] money NOT NULL CONSTRAINT CK_Storage_PurchasePrice CHECK ([Purchase Price] > 0),
	[Date] date NOT NULL
) 
GO

CREATE VIEW [ActualStorage] AS
SELECT TOP(1) WITH TIES *
FROM Storage
ORDER BY ROW_NUMBER() OVER (PARTITION BY Cell ORDER BY [Date] DESC)
GO

CREATE TABLE [Delivery](
	[ID] int PRIMARY KEY IDENTITY,
	[ProviderID] int NOT NULL REFERENCES [Provider] (ID),
	[PartID] int NOT NULL REFERENCES Part (ID),
	[Quantity] int NOT NULL CONSTRAINT CK_Delivery_Quantity CHECK (Quantity > 0),
	[Price] money NOT NULL CONSTRAINT CK_Delivery_Price CHECK (Price > 0),
	[Overhead] money NOT NULL,
	[Date] date NOT NULL
) 
GO

CREATE TABLE [Defect](
	[ID] int PRIMARY KEY IDENTITY,
	[ProviderID] int NOT NULL REFERENCES [Provider] (ID),
	[PartID] int NOT NULL REFERENCES Part (ID),
	[Quantity] int NOT NULL CONSTRAINT CK_Defect_Quantity CHECK (Quantity > 0),
	[Date] date NOT NULL
) 
GO


/* ЗАПРОСЫ */
/* 1 */
--фирмы, поставляющие двигатели
SELECT pr.[Name]
FROM [Provider] pr JOIN ProviderType t ON pr.TypeID = t.ID, Delivery d, Part p
WHERE pr.ID = d.ProviderID AND d.PartID = p.ID AND t.[Name] = 'фирма' AND p.[Name] = 'двигатель'
--магазины, поставившие не менее 100 шин за апрель 2021
SELECT pr.[Name], SUM(Quantity) Quantity
FROM [Provider] pr JOIN ProviderType t ON pr.TypeID = t.ID, Delivery d, Part p
WHERE pr.ID = d.ProviderID AND d.PartID = p.ID AND t.[Name] = 'магазин' AND p.[Name] = 'шина' 
	  AND [Date] BETWEEN '20210401' AND '20210430'
GROUP BY pr.[Name]
HAVING SUM(Quantity) > 100

/* 2 */
SELECT pr.[Name], t.[Name] [Type], Price, DeliveryIn
FROM PriceList pl JOIN Part p ON pl.PartID = p.ID
				  JOIN [Provider] pr ON pr.ID = pl.ProviderID
				  JOIN ProviderType t ON pr.TypeID = t.ID
WHERE p.[Name] = 'двигатель'

/* 3 */
--фары за неделю
SELECT b.[Name], Quantity
FROM Sale s, Part p, Buyer b
WHERE s.PartID = p.ID AND s.BuyerID = b.ID AND [Date] BETWEEN '20210419' AND '20210425' AND p.[Name] = 'фара'
--товары в объёме >= 1000
SELECT b.[Name], p.[Name] Part, Quantity
FROM Sale s, Part p, Buyer b
WHERE s.PartID = p.ID AND s.BuyerID = b.ID AND Quantity >= 1000

/* 4 */
SELECT [Name] Part, Cell, Quantity
FROM Part p JOIN ActualStorage s ON s.PartID = p.ID

/* 5 */
SELECT TOP(10)p.[Name] Part, SUM(Quantity) Quantity, [Best Purchase Price], pr.[Name] [Cheapest Provider]
FROM [Provider] pr, Part p, Sale s JOIN (SELECT PartID, MIN(Price) [Best Purchase Price]
										 FROM Delivery
										 GROUP BY PartID) s1 ON s.PartID = s1.PartID
								   JOIN (SELECT PartID, Price, ProviderID
										 FROM Delivery) s2 ON [Best Purchase Price] = s2.Price
WHERE s.PartID = p.ID AND s2.ProviderID = pr.ID AND s.PartID = s2.PartID
GROUP BY p.[Name], [Best Purchase Price], pr.[Name]
ORDER BY Quantity DESC

/* 6 */
SELECT AVG(Quantity) Average
FROM Sale s, Part p
WHERE s.PartID = p.ID AND [Date] BETWEEN '20210401' AND '20210430' AND p.[Name] = 'фара'

/* 7 */
--доля по объёмам продаж (деньги)
DECLARE @a real = (SELECT SUM(Price * Quantity) 
				   FROM Delivery, [Provider] pr
				   WHERE ProviderID = pr.ID AND pr.[Name] = 'дилер')
DECLARE @b real = (SELECT SUM(Price * Quantity)
				   FROM Delivery)
SELECT CONCAT(CASE WHEN @a IS NULL THEN 0 ELSE @a END/@b*100, '%') [Value market share]
GO
--доля по штучным продажам (единицы товара)
DECLARE @a real = (SELECT SUM(Quantity) 
				   FROM Delivery, [Provider] pr
				   WHERE ProviderID = pr.ID AND pr.[Name] = 'дилер')
DECLARE @b real = (SELECT SUM(Quantity)
				   FROM Delivery)
SELECT CONCAT(CASE WHEN @a IS NULL THEN 0 ELSE @a END/@b*100, '%') [Volume market share]
GO
--прибыль за месяц
DECLARE @d1 date = '20210401'
DECLARE @d2 date = '20210430'
DECLARE @a real = (SELECT SUM(Price * Quantity)
				   FROM Sale
				   WHERE [Date] BETWEEN @d1 AND @d2)
DECLARE @b real = (SELECT SUM(Price * Quantity + Overhead)
				   FROM Delivery
				   WHERE [Date] BETWEEN @d1 AND @d2)
SELECT @a-@b Profit
GO

/* 8 */
DECLARE @a real = (SELECT SUM(Overhead)
				   FROM Delivery)
DECLARE @b real = (SELECT SUM(Price * Quantity)
				   FROM Sale)
SELECT CONCAT(@a/@b*100, '%') Costs
GO

/* 9 */
SELECT p.[Name] Part, Stale, CONCAT(CAST(Stale AS real)/Entire*100, '%') [Percentage]
FROM Part p, (SELECT PartID, SUM(Quantity) Stale
			  FROM ActualStorage
			  WHERE [Date] BETWEEN '20200101' AND '20201231'
			  GROUP BY PartID) s1,
			 (SELECT PartID, SUM(Quantity) Entire
			  FROM ActualStorage
			  GROUP BY PartID) s2
WHERE s1.PartID = p.ID AND s2.PartID = p.ID

/* 10 */
SELECT CASE WHEN p.[Name] IS NULL THEN 'Total' ELSE p.[Name] END Part, SUM(Quantity) Quantity,
	   CASE WHEN pr.[Name] IS NULL THEN 'Total' ELSE pr.[Name] END [Provider]
FROM Part p, Defect d, [Provider] pr
WHERE PartID = p.ID AND ProviderID = pr.ID AND [Date] BETWEEN '20220101' AND '20220130'
GROUP BY ROLLUP(p.[Name], pr.[Name])

/* 11 */
SELECT [Name] Part, SUM(Quantity) Quantity, SUM(Price * Quantity) [Value]
FROM Sale s, Part p
WHERE s.PartID = p.ID AND [Date] = '20210401'
GROUP BY [Name]

/* 12 */
--приход и расход указаны относительно количества деталей на складе
DECLARE @d1 date = '20210401'
DECLARE @d2 date = '20210430'
SELECT 'Приход' [Type], [Date], p.[Name] Part, Price, Quantity, Price * Quantity [Value], pr.[Name] Trader
FROM Delivery, Part p, [Provider] pr
WHERE PartID = p.ID AND ProviderID = pr.ID AND [Date] BETWEEN @d1 AND @d2
UNION ALL
SELECT 'Расход' [Type], [Date], p.[Name] Part, Price, Quantity, Price * Quantity [Value], b.[Name]
FROM Sale, Part p, Buyer b
WHERE PartID = p.ID AND BuyerID = b.ID AND [Date] BETWEEN @d1 AND @d2
ORDER BY [Date]
GO

/* 13 */
--difference: + недостача, - избыток
SELECT [Name] Part, Price, Calc Calculated, Price * Calc [Calc value], Actual, Price * Actual [Actual value], 
	   Calc - Actual [Difference], Price * (Calc - Actual) [Diff value]
FROM (SELECT p.[Name], CASE WHEN Price IS NULL THEN 0 ELSE Price END Price, Calc, 
			 CASE WHEN Actual IS NULL THEN 0 ELSE Actual END Actual
	  FROM Part p, (SELECT s.PartID, Price 
					FROM Sale s JOIN (SELECT PartID, MAX([Date]) [Last]
									  FROM Sale
									  GROUP BY PartID) sub ON s.PartID = sub.PartID
					WHERE s.[Date] = sub.[Last]) b 
				   RIGHT JOIN (SELECT d.PartID, Delivd - CASE WHEN Sold IS NULL THEN 0 ELSE Sold END Calc
							   FROM Delivery d JOIN (SELECT PartID, SUM(Quantity) Delivd
													 FROM Delivery
													 GROUP BY PartID) s1 ON d.PartID = s1.PartID
											   LEFT JOIN (SELECT PartID, SUM(Quantity) Sold
														  FROM Sale
														  GROUP BY PartID) s2 ON s1.PartID = s2.PartID
							   GROUP BY d.PartID, Delivd - CASE WHEN Sold IS NULL THEN 0 ELSE Sold END) c ON b.PartID = c.PartID
				   LEFT JOIN (SELECT PartID, SUM(Quantity) Actual
							  FROM ActualStorage
							  GROUP BY PartID) a ON c.PartID = a.PartID
	  WHERE c.PartID = p.ID) sub

/* 14 */
DECLARE @d1 date = '20200101'
DECLARE @d2 date = '20201231'
DECLARE @n varchar(50) = 'шина'
DECLARE @a real = (SELECT SUM(Quantity * [Purchase Price])
				   FROM ActualStorage s, Part p
				   WHERE s.PartID = p.ID AND [Name] = @n AND [Date] < @d1) --остатки на начало периода
DECLARE @b real = (SELECT SUM(Quantity * [Purchase Price])
				   FROM ActualStorage s, Part p
				   WHERE s.PartID = p.ID AND [Name] = @n AND [Date] < @d2) --остатки на конец периода
DECLARE @c real = (SELECT SUM(Price * Quantity)
				   FROM Sale s, Part p
				   WHERE s.PartID = p.ID AND [Name] = @n AND [Date] BETWEEN @d1 AND @d2) --объём продаж
SELECT (@a+@b)/2 * DATEDIFF(day, @d1, @d2) / @c [Product turnover (days)]
GO

/* 15 */
DECLARE @a varchar(50) = (SELECT [definition]
						  FROM sys.check_constraints
						  WHERE [name] = 'CK_Storage_Cell_Numbers')
DECLARE @i int = PATINDEX('%[123456789]%', @a)
DECLARE @b varchar(50) = SUBSTRING(@a, @i, 10)
SET @i = PATINDEX('%[^0123456789]%', @b)
IF @i > 0 
	SET @b = LEFT(@b, @i-1)
SET @i = CAST(@b AS int)
SELECT @i - COUNT(*) [Empty cells]
FROM ActualStorage
WHERE Quantity > 0
GO

/* 16 */
--перечень
SELECT b.[Name], p.[Name] Part, Quantity, Price, Quantity * Price [Value]
FROM Request, Part p, Buyer b
WHERE PartID = p.ID AND BuyerID = b.ID
--общая сумма
SELECT SUM(Quantity * Price) Total
FROM Request