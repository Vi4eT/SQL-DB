--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'DrugstoreDB'
GO
USE [master]
GO
ALTER DATABASE [DrugstoreDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [DrugstoreDB]
GO

-- 15 --
--TODO: совместить sale и order?, fine tuning, размеры varchar
--Create DB
CREATE DATABASE [DrugstoreDB]
GO

USE [DrugstoreDB]
GO

CREATE TABLE [DrugType]
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(10) NOT NULL
)
GO

INSERT INTO DrugType ([Name]) VALUES 
	('Таблетки'), 
	('Мазь'), 
	('Настойка'),
	('Микстура'), 
	('Раствор'),
	('Порошок')
GO

CREATE TABLE Drug
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[TypeID] tinyint NOT NULL REFERENCES DrugType (ID),
	[Price] money NOT NULL CONSTRAINT CK_Drug_Price CHECK (Price > 0),
	[Amount] int NOT NULL CONSTRAINT CK_Drug_Amount CHECK (Amount >= 0),
	[CriticalAmount] int NOT NULL CONSTRAINT CK_Drug_CriticalAmount CHECK (CriticalAmount > 0)
)
GO

CREATE TABLE Component
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[Price] money NOT NULL CONSTRAINT CK_Component_Price CHECK (Price > 0),
	[Amount] int NOT NULL CONSTRAINT CK_Component_Amount CHECK (Amount >= 0),
	[CriticalAmount] int NOT NULL CONSTRAINT CK_Component_CriticalAmount CHECK (CriticalAmount > 0)
)
GO

CREATE TABLE Tech
(
	[ID] int PRIMARY KEY IDENTITY,
	[DrugID] int NOT NULL REFERENCES Drug (ID),
	[Description] varchar(200) NOT NULL
)
GO

CREATE TABLE Client
(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(50) NOT NULL,
	[Birthdate] date NOT NULL,
	[Address] varchar(50) NOT NULL,
	[Phone] varchar(50) NOT NULL
)
GO

CREATE TABLE Doctor
(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(50) NOT NULL
)
GO

CREATE TABLE Recipe
(
	[ID] int PRIMARY KEY IDENTITY,
	[ClientID] int NOT NULL REFERENCES Client (ID),
	[DoctorID] int NOT NULL REFERENCES Doctor (ID),
	[Diagnosis] varchar(50) NOT NULL
)
GO

CREATE TABLE Sale
(
	[ID] int PRIMARY KEY IDENTITY,
	[ClientID] int NOT NULL REFERENCES Client (ID),
	[RecipeID] int NULL REFERENCES Recipe (ID),
	[DrugID] int NOT NULL REFERENCES Drug (ID),
	[Date] date NOT NULL DEFAULT GETDATE() CONSTRAINT CK_Sale_Date CHECK ([Date] <= GETDATE()),
	[Amount] int NOT NULL CONSTRAINT CK_Sale_Amount CHECK (Amount > 0)
)
GO

CREATE TABLE [OrderStatus]
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(16) NOT NULL
)
GO

INSERT INTO OrderStatus ([Name]) VALUES 
	('Нет компонентов'), 
	('В производстве'), 
	('Готов к выдаче'), 
	('Выполнен')
GO

CREATE TABLE [Order]
(
	[ID] int PRIMARY KEY IDENTITY,
	[RecipeID] int NOT NULL REFERENCES Recipe (ID),
	[OrderDate] date NOT NULL DEFAULT GETDATE() CONSTRAINT CK_Order_OrderDate CHECK (OrderDate <= GETDATE()),
	[ManufactureDate] date NULL CONSTRAINT CK_Order_ManufactureDate CHECK (ManufactureDate <= GETDATE()),
	[CompletionDate] date NULL CONSTRAINT CK_Order_CompletionDate CHECK (CompletionDate <= GETDATE()),
	[Price] money NOT NULL CONSTRAINT CK_Order_Price CHECK (Price > 0),
	[StatusID] tinyint NOT NULL REFERENCES OrderStatus (ID),
	CONSTRAINT CK_Order_Dates CHECK (OrderDate <= ManufactureDate AND ManufactureDate <= CompletionDate)
)
GO

CREATE TABLE Prescription
(
	[RecipeID] int NOT NULL REFERENCES Recipe (ID),
	[DrugID] int NOT NULL REFERENCES Drug (ID),
	[Amount] int NOT NULL CONSTRAINT CK_Prescription_Amount CHECK (Amount > 0),
	PRIMARY KEY (RecipeID, DrugID)
)
GO

CREATE TABLE Composition
(
	[DrugID] int NOT NULL REFERENCES Drug (ID),
	[ComponentID] int NOT NULL REFERENCES Component (ID),
	[Amount] int NOT NULL CONSTRAINT CK_Composition_Amount CHECK (Amount > 0),
	PRIMARY KEY (DrugID, ComponentID)
)
GO

--Queries
--1
SELECT DISTINCT FIO, Birthdate, Phone, [Address]
FROM Client c JOIN Recipe r ON c.ID = r.ClientID
			  JOIN [Order] o ON r.ID = o.RecipeID
			  JOIN OrderStatus os ON o.StatusID = os.ID
WHERE ManufactureDate < CAST(GETDATE() AS date) AND [Name] = 'готов к выдаче'

--2
--в целом
SELECT DISTINCT FIO, Birthdate, Phone, [Address]
FROM Client c JOIN Recipe r ON c.ID = r.ClientID
			  JOIN [Order] o ON r.ID = o.RecipeID
			  JOIN OrderStatus os ON o.StatusID = os.ID
WHERE os.[Name] = 'нет компонентов'
--категория
SELECT DISTINCT FIO, Birthdate, Phone, [Address]
FROM Client c JOIN Recipe r ON c.ID = r.ClientID
			  JOIN [Order] o ON r.ID = o.RecipeID
			  JOIN OrderStatus os ON o.StatusID = os.ID
			  JOIN Prescription p ON r.ID = p.RecipeID
			  JOIN Drug d ON d.ID = p.DrugID
			  JOIN DrugType dt ON d.TypeID = dt.ID
WHERE os.[Name] = 'нет компонентов' AND dt.[Name] = 'мазь'

--3
--в целом
SELECT TOP(10) [Name], SUM(s.Amount) Used
FROM Sale s JOIN Drug d ON s.DrugID = d.ID
GROUP BY [Name]
ORDER BY SUM(s.Amount) DESC
--категория
SELECT TOP(10) d.[Name], SUM(s.Amount) Used
FROM Sale s JOIN Drug d ON s.DrugID = d.ID
			JOIN DrugType dt ON d.TypeID = dt.ID
WHERE dt.[Name] = 'таблетки'
GROUP BY d.[Name]
ORDER BY SUM(s.Amount) DESC

--4
SELECT [Name], SUM(s.Amount) Used
FROM Sale s JOIN Drug d ON s.DrugID = d.ID
WHERE [Name] = 'найз' AND [Date] BETWEEN '20220101' AND '20220201'
GROUP BY [Name]

--5 
--лекарство
SELECT DISTINCT FIO, Birthdate, Phone, [Address]
FROM Client c JOIN Recipe r ON c.ID = r.ClientID
			  JOIN [Order] o ON r.ID = o.RecipeID
			  JOIN Prescription p ON r.ID = p.RecipeID
			  JOIN Drug d ON d.ID = p.DrugID
WHERE d.[Name] = 'парацетамол' AND OrderDate BETWEEN '20220201' AND '20220301'
--тип
SELECT DISTINCT FIO, Birthdate, Phone, [Address]
FROM Client c JOIN Recipe r ON c.ID = r.ClientID
			  JOIN [Order] o ON r.ID = o.RecipeID
			  JOIN Prescription p ON r.ID = p.RecipeID
			  JOIN Drug d ON d.ID = p.DrugID
			  JOIN DrugType dt ON d.TypeID = dt.ID
WHERE dt.[Name] = 'таблетки' AND OrderDate BETWEEN '20220201' AND '20220301'

--6
SELECT d.[Name], dt.[Name] [Type]
FROM Drug d JOIN DrugType dt ON d.TypeID = dt.ID
WHERE Amount <= CriticalAmount

--7 
--в целом
SELECT [Name], Amount
FROM Drug
WHERE Amount <= 50
--категория
SELECT d.[Name], Amount
FROM Drug d JOIN DrugType dt ON d.TypeID = dt.ID
WHERE Amount <= 50 AND dt.[Name] = 'таблетки'

--8
SELECT o.ID, OrderDate, Price
FROM [Order] o JOIN OrderStatus os ON o.StatusID = os.ID
WHERE [Name] = 'в производстве'

--9
SELECT d.[Name], SUM(p.Amount) Amount
FROM Prescription p JOIN Drug d ON p.DrugID = d.ID
					JOIN [Order] o ON o.RecipeID = p.RecipeID
					JOIN OrderStatus os ON o.StatusID = os.ID
WHERE os.[Name] = 'в производстве'
GROUP BY d.[Name]

--10 
--тип
SELECT d.[Name], [Description]
FROM Tech t JOIN Drug d ON t.DrugID = d.ID
			JOIN DrugType dt ON d.TypeID = dt.ID
WHERE dt.[Name] = 'мазь'
--лекарство
SELECT [Name], [Description]
FROM Tech t JOIN Drug d ON t.DrugID = d.ID
WHERE [Name] = 'парацетамол'
--в производстве
SELECT DISTINCT d.[Name], [Description]
FROM [Order] o JOIN Prescription p ON p.RecipeID = o.RecipeID
			   JOIN Drug d ON p.DrugID = d.ID
			   JOIN Tech t ON t.DrugID = d.ID
			   JOIN OrderStatus os ON o.StatusID = os.ID
WHERE os.[Name] = 'в производстве'

--11
DECLARE @n varchar(50) = 'терафлю'
SELECT [Name], 'Лекарство' [Type], Price, Amount
FROM Drug
WHERE [Name] = @n
UNION
SELECT c.[Name], 'Компонент' [Type], c.Price, co.Amount
FROM Drug d JOIN Composition co ON d.ID = co.DrugID
			JOIN Component c ON co.ComponentID = c.ID
WHERE d.[Name] = @n
ORDER BY [Type] DESC
GO

--12
--название
SELECT FIO, Birthdate, [Address], Phone, COUNT(d.[Name]) Amount
FROM Client c JOIN Recipe r ON c.ID = r.ClientID
			  JOIN Prescription p ON r.ID = p.RecipeID
			  JOIN Drug d ON p.DrugID = d.ID
WHERE d.[Name] = 'найз'
GROUP BY FIO, Birthdate, [Address], Phone
ORDER BY COUNT(d.[Name]) DESC
--тип
SELECT FIO, Birthdate, [Address], Phone, COUNT(dt.[Name]) Amount
FROM Client c JOIN Recipe r ON c.ID = r.ClientID
			  JOIN Prescription p ON r.ID = p.RecipeID
			  JOIN Drug d ON p.DrugID = d.ID
			  JOIN DrugType dt ON d.TypeID = dt.ID
WHERE dt.[Name] = 'порошок'
GROUP BY FIO, Birthdate, [Address], Phone
ORDER BY COUNT(dt.[Name]) DESC

--13
DECLARE @n varchar(50) = 'колдакт'
SELECT d.[Name], dt.[Name] [Type], [Description], Price, Amount
FROM Drug d JOIN DrugType dt ON d.TypeID = dt.ID
			JOIN Tech t ON d.ID = t.DrugID
WHERE d.[Name] = @n
UNION
SELECT c.[Name], 'Компонент' [Type], NULL [Description], c.Price, co.Amount
FROM Drug d JOIN Composition co ON d.ID = co.DrugID
			JOIN Component c ON co.ComponentID = c.ID
WHERE d.[Name] = @n
ORDER BY [Description] DESC
GO