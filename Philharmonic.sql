--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'PhilDB'
GO
USE [master]
GO
ALTER DATABASE [PhilDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [PhilDB]
GO

-- 25 --
--Create DB
CREATE DATABASE [PhilDB]
GO

USE [PhilDB]
GO

CREATE TABLE BuildingType
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
) 
GO

INSERT INTO BuildingType ([Name]) VALUES
	('Концертный зал'), 
	('Театр'),
	('Концертная площадка'),
	('Эстрада'),
	('Дворец культуры'),
	('Кинотеатр') --не может выступать артист, нет импресарио, только организатор
GO

CREATE TABLE ParameterType
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
) 
GO

INSERT INTO ParameterType ([Name]) VALUES
	('Вместимость'), 
	('Высота сцены'),
	('Ширина сцены'),
	('Площадь')
GO

CREATE TABLE Building
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[TypeID] tinyint NOT NULL REFERENCES BuildingType (ID)
)
GO

CREATE TABLE BuildingParameter
(
	[BuildingID] int NOT NULL REFERENCES Building (ID),
	[TypeID] tinyint NOT NULL REFERENCES ParameterType (ID),
	[Value] int NOT NULL,
	PRIMARY KEY (BuildingID, TypeID)
) 
GO

CREATE TABLE Employee
(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(50) NOT NULL,
	[IsArtist] bit NOT NULL
)
GO

CREATE TABLE Genre
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
) 
GO

INSERT INTO Genre ([Name]) VALUES
	('Театр'), 
	('Кино'),
	('Цирк'),
	('Мюзикл'),
	('Вокал')
GO

CREATE TABLE Organizer
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
) 
GO

CREATE TABLE [Event]
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[Type] varchar(10) NOT NULL CONSTRAINT CK_Event_Type CHECK ([Type] IN ('Концерт', 'Конкурс')),
	[BuildingID] int NOT NULL REFERENCES Building (ID),
	[OrganizerID] int NOT NULL REFERENCES Organizer (ID),
	[StartDate] date NOT NULL,
	[EndDate] date NOT NULL,
	CONSTRAINT CK_Event_Dates CHECK (StartDate <= EndDate)
) 
GO

CREATE FUNCTION isartist(@ID int) RETURNS bit AS
BEGIN
	RETURN (SELECT IsArtist
			FROM Employee
			WHERE @ID = ID)
END
GO

CREATE TABLE ArtistImpresario
(
	[ArtistID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_ArtistImpresario_ArtistID CHECK (dbo.isartist(ArtistID) = 1),
	[ImpresarioID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_ArtistImpresario_ImpresarioID CHECK (dbo.isartist(ImpresarioID) = 0),
	PRIMARY KEY (ArtistID, ImpresarioID)
)
GO

CREATE TABLE EmployeeGenre
(
	[EmployeeID] int NOT NULL REFERENCES Employee (ID),
	[GenreID] tinyint NOT NULL REFERENCES Genre (ID),
	PRIMARY KEY (EmployeeID, GenreID)
)
GO

CREATE FUNCTION iscontest(@ID int) RETURNS bit AS
BEGIN
	IF (SELECT [Type]
		FROM [Event]
		WHERE @ID = ID) LIKE 'конкурс'
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE ContestArtist
(
	[ContestID] int NOT NULL REFERENCES [Event] (ID)
		CONSTRAINT CK_ContestArtist_ContestID CHECK (dbo.iscontest(ContestID) = 1),
	[ArtistID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_ContestArtist_ArtistID CHECK (dbo.isartist(ArtistID) = 1),
	[IsWinner] bit NOT NULL,
	PRIMARY KEY (ContestID, ArtistID)
)
GO


--Queries
--1
--тип
SELECT b.[Name]
FROM Building b JOIN BuildingType bt ON b.TypeID = bt.ID
WHERE bt.[Name] = 'театр'
--тип и параметр
SELECT b.[Name], [Value]
FROM Building b JOIN BuildingType bt ON b.TypeID = bt.ID
				JOIN BuildingParameter bp ON b.ID = bp.BuildingID
				JOIN ParameterType pt ON bp.TypeID = pt.ID
WHERE bt.[Name] = 'театр' AND pt.[Name] = 'вместимость' AND [Value] >= 1000

--2
SELECT FIO
FROM EmployeeGenre eg JOIN Employee e ON eg.EmployeeID = e.ID
					  JOIN Genre g ON eg.GenreID = g.ID
WHERE [Name] = 'мюзикл'

--3
SELECT e.FIO
FROM ArtistImpresario ai JOIN Employee e ON ai.ArtistID = e.ID
						 JOIN Employee ee ON ai.ImpresarioID = ee.ID
WHERE ee.FIO = 'Блинов Егор Александрович'

--4
SELECT e.FIO, g.[Name] Genre
FROM Employee e JOIN EmployeeGenre eg ON e.ID = eg.EmployeeID
				JOIN Genre g ON eg.GenreID = g.ID
WHERE EmployeeID IN (SELECT EmployeeID
					 FROM EmployeeGenre
					 GROUP BY EmployeeID
					 HAVING COUNT(EmployeeID) > 1)

--5
SELECT e.FIO
FROM ArtistImpresario ai JOIN Employee ee ON ai.ArtistID = ee.ID
						 JOIN Employee e ON ai.ImpresarioID = e.ID
WHERE ee.FIO = 'Фомин Валерий Константинович'

--6
--все
SELECT e.[Name], b.[Name] Place, o.[Name] Organizer, StartDate, EndDate
FROM [Event] e JOIN Building b ON e.BuildingID = b.ID
			   JOIN Organizer o ON e.OrganizerID = o.ID
WHERE [Type] = 'концерт' AND StartDate >= '20210701' AND EndDate <= '20220101'
--организатор
SELECT e.[Name], b.[Name] Place, StartDate, EndDate
FROM [Event] e JOIN Building b ON e.BuildingID = b.ID
			   JOIN Organizer o ON e.OrganizerID = o.ID
WHERE [Type] = 'концерт' AND StartDate >= '20210701' AND EndDate <= '20220101' AND o.[Name] = 'ООО Акрополь'

--7
SELECT FIO
FROM ContestArtist ca JOIN [Event] e ON ca.ContestID = e.ID
					  JOIN Employee em ON ca.ArtistID = em.ID
WHERE [Name] = 'Конкурс театральных постановок "Маскарад"' AND IsWinner = 1

--8
SELECT e.[Name], o.[Name] Organizer, StartDate, EndDate
FROM [Event] e JOIN Building b ON e.BuildingID = b.ID
			   JOIN Organizer o ON e.OrganizerID = o.ID
WHERE [Type] = 'концерт' AND b.[Name] = 'Мариинский театр'

--9
SELECT FIO
FROM Employee e JOIN EmployeeGenre eg ON e.ID = eg.EmployeeID
				JOIN Genre g ON eg.GenreID = g.ID
WHERE [Name] = 'вокал' AND IsArtist = 0

--10
SELECT FIO
FROM Employee
WHERE IsArtist = 1
EXCEPT
SELECT DISTINCT FIO
FROM Employee em JOIN ContestArtist ca ON em.ID = ca.ArtistID
				 JOIN [Event] e ON ca.ContestID = e.ID
WHERE StartDate >= '20210101' AND EndDate <= '20220101'

--11
SELECT o.[Name], COUNT(OrganizerID) Number
FROM Organizer o JOIN [Event] e ON o.ID = e.OrganizerID
WHERE StartDate >= '20210701' AND EndDate <= '20220101'
GROUP BY o.[Name]

--12
SELECT b.[Name], e.[Name], StartDate, EndDate
FROM Building b JOIN [Event] e ON b.ID = e.BuildingID
WHERE StartDate >= '20220201' AND EndDate <= '20220301'