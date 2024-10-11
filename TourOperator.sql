--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'TourOperatorDB'
GO
USE [master]
GO
ALTER DATABASE [TourOperatorDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [TourOperatorDB]
GO

-- 14 --
--Create DB
CREATE DATABASE [TourOperatorDB]
GO

USE [TourOperatorDB]
GO

CREATE FUNCTION get_birthday(@PassportID bigint) RETURNS date AS
BEGIN
	RETURN (SELECT Birthday
			FROM Tourist
			WHERE @PassportID = PassportID)
END
GO

CREATE FUNCTION get_age(@d1 date) RETURNS int AS
BEGIN
	DECLARE @d2 date = GETDATE()
	DECLARE @age int = DATEDIFF(year, @d1, @d2)
	IF DATEADD(year, -@age, @d2) < @d1 
		SELECT @age = @age-1
	RETURN @age
END
GO

CREATE FUNCTION check_responsible(@Birthday date, @ResponsibleID bigint) RETURNS bit AS
BEGIN
	IF dbo.get_age(@Birthday) < 18 AND @ResponsibleID IS NULL
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE [Tourist](
	[PassportID] bigint PRIMARY KEY,
	[Surname] varchar(50) NOT NULL,
	[Name] varchar(50) NOT NULL,
	[Patronymic] varchar(50) NOT NULL,
	[Type] varchar(10) NOT NULL CONSTRAINT CK_Tourist_Type CHECK ([Type] IN ('Отдых', 'Шопинг')),
	[Sex] char(1) NOT NULL CONSTRAINT CK_Tourist_Sex CHECK (Sex IN ('М', 'Ж')),
	[Birthday] date NOT NULL,
	[ResponsibleID] bigint NULL REFERENCES [Tourist] 
		CONSTRAINT CK_Tourist_Responsible_Age CHECK (dbo.get_age(dbo.get_birthday(ResponsibleID)) >= 18),
	CONSTRAINT CK_Tourist_Kids CHECK (dbo.check_responsible(Birthday, ResponsibleID) = 0)
) 
GO

CREATE TABLE [Agency](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
) 
GO

CREATE TABLE [Excursion](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[AgencyID] int NOT NULL REFERENCES [Agency] (ID),
	[Price] money NOT NULL
) 
GO

CREATE FUNCTION get_tourist_type(@PassportID bigint) RETURNS varchar(10) AS
BEGIN
	RETURN (SELECT [Type]
			FROM Tourist
			WHERE @PassportID = PassportID)
END
GO

CREATE FUNCTION get_responsibleID(@PassportID bigint) RETURNS bigint AS
BEGIN
	RETURN (SELECT ResponsibleID
			FROM Tourist
			WHERE PassportID = @PassportID)
END
GO

CREATE FUNCTION check_excursion(@PassportID bigint, @ExcursionID int, @Date date) RETURNS bit AS
BEGIN
	IF dbo.get_age(dbo.get_birthday(@PassportID)) < 18
	BEGIN
		DECLARE @e int, @d date
		SELECT @e = ExcursionID, @d = [Date]
		FROM Schedule
		WHERE PassportID = dbo.get_responsibleID(@PassportID)
		IF @ExcursionID = @e AND @Date = @d
			RETURN 0
		RETURN 1
	END
	RETURN 0
END
GO

CREATE FUNCTION check_date(@PassportID bigint, @Date date) RETURNS bit AS
BEGIN
	DECLARE @d1 date, @d2 date
	SELECT @d1 = StartDate, @d2 = EndDate
	FROM TouristTour
	WHERE PassportID = @PassportID AND StartDate = (SELECT MAX(StartDate)
													FROM TouristTour
													WHERE PassportID = @PassportID)
								   AND EndDate = (SELECT MAX(EndDate)
												  FROM TouristTour
												  WHERE PassportID = @PassportID)
	IF @Date BETWEEN @d1 AND @d2
		RETURN 0
	RETURN 1
END
GO

CREATE TABLE [Schedule](
	[ID] int PRIMARY KEY IDENTITY,
	[PassportID] bigint NOT NULL REFERENCES [Tourist] (PassportID)
		CONSTRAINT CK_Schedule_PassportID_Type CHECK (dbo.get_tourist_type(PassportID) = 'Отдых'),
	[ExcursionID] int NOT NULL REFERENCES [Excursion] (ID),
	[Date] date NOT NULL,
	CONSTRAINT CK_Schedule_Date CHECK (dbo.check_date(PassportID, [Date]) = 0),
	CONSTRAINT CK_Schedule_Excursion_SameAsResponsible CHECK (dbo.check_excursion(PassportID, ExcursionID, [Date]) = 0)
) 
GO

CREATE FUNCTION check_cargo_plane(@Type varchar(20), @IsStartPlane bit) RETURNS bit AS
BEGIN
	IF @Type = 'Грузовой'
		RETURN @IsStartPlane
	RETURN 0
END
GO

CREATE TABLE [Plane](
	[ID] int PRIMARY KEY IDENTITY,
	[Type] varchar(20) NOT NULL CONSTRAINT CK_Plane_Type CHECK ([Type] IN ('Пассажирский', 'Грузопассажирский', 'Грузовой')),
	[Name] varchar(50) NOT NULL,
	[IsStartPlane] bit NOT NULL,
	[Price] money NOT NULL,
	CONSTRAINT CK_Plane_IsStartPlane_Cargo CHECK (dbo.check_cargo_plane([Type], IsStartPlane) = 0)
) 
GO

CREATE TABLE [Hotel](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[Price] money NOT NULL
) 
GO

CREATE TABLE [Tour](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[Price] money NOT NULL
)
GO

CREATE FUNCTION is_start_plane(@ID int) RETURNS bit AS
BEGIN
	RETURN (SELECT IsStartPlane
			FROM Plane
			WHERE @ID = ID)
END
GO

CREATE FUNCTION get_plane_type(@ID int) RETURNS varchar(20) AS
BEGIN
	RETURN (SELECT [Type]
			FROM Plane
			WHERE @ID = ID)
END
GO

CREATE FUNCTION check_hotel(@PassportID bigint, @HotelID int) RETURNS bit AS
BEGIN
	IF dbo.get_age(dbo.get_birthday(@PassportID)) < 18
	BEGIN
		DECLARE @r bigint = dbo.get_responsibleID(@PassportID)
		IF @HotelID = (SELECT HotelID
					   FROM TouristTour
					   WHERE PassportID = @r AND StartDate = (SELECT MAX(StartDate)
															  FROM TouristTour
															  WHERE PassportID = @r))
			RETURN 0
		RETURN 1
	END
	RETURN 0
END
GO

CREATE FUNCTION check_tour(@PassportID bigint, @TourID int) RETURNS bit AS
BEGIN
	IF dbo.get_age(dbo.get_birthday(@PassportID)) < 18
	BEGIN
		DECLARE @r bigint = dbo.get_responsibleID(@PassportID)
		IF @TourID = (SELECT TourID
					  FROM TouristTour
					  WHERE PassportID = @r AND StartDate = (SELECT MAX(StartDate)
															 FROM TouristTour
															 WHERE PassportID = @r))
			RETURN 0
		RETURN 1
	END
	RETURN 0
END
GO

CREATE TABLE [TouristTour](
	[ID] int PRIMARY KEY IDENTITY,
	[PassportID] bigint NOT NULL REFERENCES [Tourist] (PassportID),
	[TourID] int NOT NULL REFERENCES [Tour] (ID),
	[StartDate] date NOT NULL,
	[StartPlaneID] int NOT NULL REFERENCES [Plane] (ID) 
		CONSTRAINT CK_TouristTour_StartPlane_Check CHECK (dbo.is_start_plane(StartPlaneID) = 1),
	[EndDate] date NOT NULL,
	[EndPlaneID] int NOT NULL REFERENCES [Plane] (ID)
		CONSTRAINT CK_TouristTour_EndPlane_Check CHECK (dbo.is_start_plane(EndPlaneID) = 0),
	[HotelID] int NOT NULL REFERENCES [Hotel] (ID),
	CONSTRAINT CK_TouristTour_EndPlane_Type CHECK (dbo.get_plane_type(EndPlaneID) != 'Грузовой'),
	CONSTRAINT CK_TouristTour_Hotel_SameAsResponsible CHECK (dbo.check_hotel(PassportID, HotelID) = 0),
	CONSTRAINT CK_TouristTour_Tour_SameAsResponsible CHECK (dbo.check_tour(PassportID, TourID) = 0),
	CONSTRAINT CK_TouristTour_EndDate CHECK (EndDate >= StartDate)
) 
GO

CREATE TABLE [Cargo](
	[ID] int PRIMARY KEY IDENTITY,
	[PassportID] bigint NOT NULL REFERENCES [Tourist] (PassportID)
		CONSTRAINT CK_Cargo_PassportID_Type CHECK (dbo.get_tourist_type(PassportID) = 'Шопинг'),
	[Name] varchar(50) NOT NULL,
	[Date] date NOT NULL,
	[PlaneID] int NOT NULL REFERENCES [Plane] (ID)
		CONSTRAINT CK_Cargo_Plane_Type CHECK (dbo.get_plane_type(PlaneID) != 'Пассажирский'),
	[Places] int NOT NULL,
	[Weight] int NOT NULL,
	[PackingCost] money NOT NULL,
	[InsuranceCost] money NOT NULL,
	[Total] AS PackingCost + InsuranceCost,
	CONSTRAINT CK_Cargo_Plane_Check CHECK (dbo.is_start_plane(PlaneID) = 0)
)
GO

CREATE TABLE [FinanceType](
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) UNIQUE NOT NULL
) 
GO

INSERT INTO FinanceType ([Name]) VALUES 
	('Гостиница'), 
	('Перевозка'),
	('Перелет'),
	('Экскурсия'),
	('Виза'),
	('Обслуживание самолета'),
	('Хранение груза'),
	('Путевка'),
	('Услуги представительства')
GO

CREATE FUNCTION check_finance_type(@TouristTourID int, @TypeID tinyint) RETURNS bit AS
BEGIN
	DECLARE @p bigint = (SELECT PassportID
						 FROM TouristTour
						 WHERE @TouristTourID = ID)
	DECLARE @t1 varchar(20) = dbo.get_tourist_type(@p)
	DECLARE @t2 varchar(50) = (SELECT [Name]
							   FROM FinanceType
							   WHERE @TypeID = ID)
	IF @t1 = 'Отдых' AND @t2 = 'Хранение груза'
		RETURN 1
	IF @t1 = 'Шопинг' AND @t2 = 'Экскурсия'
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE [Income](
	[ID] int PRIMARY KEY IDENTITY,
	[TouristTourID] int NOT NULL REFERENCES [TouristTour] (ID),
	[TypeID] tinyint NOT NULL REFERENCES [FinanceType] (ID),
	[Amount] money NOT NULL,
	[Date] date NOT NULL,
	CONSTRAINT CK_Income_Type CHECK (dbo.check_finance_type(TouristTourID, TypeID) = 0)
) 
GO

CREATE TABLE [Expense](
	[ID] int PRIMARY KEY IDENTITY,
	[TouristTourID] int NOT NULL REFERENCES [TouristTour] (ID),
	[TypeID] tinyint NOT NULL REFERENCES [FinanceType] (ID),
	[Amount] money NOT NULL,
	[Date] date NOT NULL,
	CONSTRAINT CK_Expense_Type CHECK (dbo.check_finance_type(TouristTourID, TypeID) = 0)
) 
GO


/*** ЗАПРОСЫ ***/
/*** 1 ***/
--все
SELECT *
FROM Tourist
--указанной категории
SELECT *
FROM Tourist
WHERE [Type] = 'Отдых'

/*** 2 ***/
--указанная гостиница
SELECT DISTINCT t.*
FROM Tourist t, TouristTour tt, Hotel h
WHERE t.PassportID = tt.PassportID AND tt.HotelID = h.ID AND h.[Name] = 'no-tell'
--указанные гостиница и категория
SELECT DISTINCT t.*
FROM Tourist t, TouristTour tt, Hotel h
WHERE t.PassportID = tt.PassportID AND tt.HotelID = h.ID AND h.[Name] = 'no-tell' AND [Type] = 'Отдых'

/*** 3 ***/
--все
SELECT COUNT(DISTINCT PassportID) Quantity
FROM TouristTour
WHERE StartDate BETWEEN '20200101' AND '20210515'
--указанной категории
SELECT COUNT(DISTINCT PassportID) Quantity
FROM TouristTour
WHERE StartDate BETWEEN '20200101' AND '20210515' AND dbo.get_tourist_type(PassportID) = 'Отдых'

/*** 4 ***/
--количество посещений
SELECT COUNT(PassportID) [Visit count]
FROM TouristTour
WHERE PassportID = 32165446
--даты посещений, отели
SELECT StartDate, EndDate, [Name] Hotel
FROM TouristTour, Hotel
WHERE PassportID = 32165446 AND HotelID = Hotel.ID
--экскурсии
SELECT [Name] Excursion, [Date]
FROM Schedule, Excursion
WHERE PassportID = 32165446 AND ExcursionID = Excursion.ID
--грузы
SELECT [Date], PlaneID, Places, [Weight], PackingCost, InsuranceCost, Total
FROM Cargo
WHERE PassportID = 69876468

/*** 5 ***/
--гостиницы
SELECT [Name], COUNT(HotelID) [Rooms occupied]
FROM Hotel, (SELECT HotelID
			 FROM TouristTour t, (SELECT PassportID, MAX(EndDate) [Date]
								  FROM TouristTour
								  WHERE EndDate >= GETDATE()
								  GROUP BY PassportID) s1
			 WHERE t.PassportID = s1.PassportID AND t.EndDate = s1.[Date]) sub
WHERE HotelID = ID
GROUP BY [Name]
--количество человек за период
SELECT [Name], COUNT(HotelID) Quantity
FROM Hotel, (SELECT DISTINCT PassportID, HotelID
			 FROM TouristTour
			 WHERE StartDate BETWEEN '20200101' AND '20211231') s1
WHERE HotelID = ID
GROUP BY [Name]

/*** 6 ***/
SELECT COUNT(DISTINCT PassportID) Quantity
FROM Schedule
WHERE [Date] BETWEEN '20200101' AND '20211231'

/*** 7 ***/
--экскурсии по популярности
SELECT [Name] Excursion, COUNT(ExcursionID) [Orders quantity]
FROM Schedule, Excursion e
WHERE ExcursionID = e.ID
GROUP BY [Name]
ORDER BY COUNT(ExcursionID) DESC
--агентства по популярности
SELECT a.[Name] Agency, SUM(Orders) [Orders quantity]
FROM Agency a, Excursion e, (SELECT ExcursionID, COUNT(ExcursionID) Orders
							 FROM Schedule
							 GROUP BY ExcursionID) sub
WHERE e.ID = ExcursionID AND a.ID = AgencyID
GROUP BY a.[Name]
ORDER BY SUM(Orders) DESC

/*** 8 ***/
--рейс туда, занятые места
SELECT COUNT(StartPlaneID) [Places occupied]
FROM TouristTour, Plane p
WHERE p.ID = StartPlaneID AND [Name] = 'рейс1' AND StartDate = '20210402'
--рейс обратно, занятые места
SELECT COUNT(EndPlaneID) [Places occupied]
FROM TouristTour, Plane p
WHERE p.ID = EndPlaneID AND [Name] = 'рейс4' AND EndDate = '20210416'
--груз
SELECT SUM(Places) [Cargo Places], SUM([Weight]) [Weight]
FROM Cargo, Plane p
WHERE p.ID = PlaneID AND p.[Name] = 'рейс5' AND [Date] = '20210501'

/*** 9 ***/
DECLARE @d1 date = '20210501'
DECLARE @d2 date = '20210515'
SELECT s1.Planes [Cargo planes], s2.Planes [Combined planes], s1.Planes + s2.Planes [Planes total], 
	   s1.Places + s2.Places [Cargo places total], s1.[Weight] + s2.[Weight] [Weight total]
FROM (SELECT COUNT(DISTINCT CONCAT(PlaneID, [Date])) Planes, SUM(Places) Places, SUM([Weight]) [Weight]
	  FROM Cargo
	  WHERE [Date] BETWEEN @d1 AND @d2 AND dbo.get_plane_type(PlaneID) = 'Грузовой') s1,
	 (SELECT COUNT(DISTINCT CONCAT(PlaneID, [Date])) Planes, SUM(Places) Places, SUM([Weight]) [Weight]
	  FROM Cargo
	  WHERE [Date] BETWEEN @d1 AND @d2 AND dbo.get_plane_type(PlaneID) = 'Грузопассажирский') s2
GO

/*** 10 ***/
--все
SELECT 'Доход' [Type], TouristTourID, [Name], Amount, [Date]
FROM Income, FinanceType t
WHERE TypeID = t.ID
UNION ALL
SELECT 'Расход' [Type], TouristTourID, [Name], Amount, [Date]
FROM Expense, FinanceType t
WHERE TypeID = t.ID
--указанной категории
DECLARE @t varchar(10) = 'Шопинг'
SELECT 'Доход' [Type], TouristTourID, [Name], Amount, [Date]
FROM Income, FinanceType t, TouristTour 
WHERE TypeID = t.ID AND TouristTourID = TouristTour.ID AND dbo.get_tourist_type(PassportID) = @t
UNION ALL
SELECT 'Расход' [Type], TouristTourID, [Name], Amount, [Date]
FROM Expense, FinanceType t, TouristTour 
WHERE TypeID = t.ID AND TouristTourID = TouristTour.ID AND dbo.get_tourist_type(PassportID) = @t
GO

/*** 11 ***/
DECLARE @d1 date = '20210101'
DECLARE @d2 date = '20210430'
SELECT 'Доход' [Type], TouristTourID, [Name], Amount, [Date]
FROM Income, FinanceType t
WHERE TypeID = t.ID AND [Date] BETWEEN @d1 AND @d2
UNION ALL
SELECT 'Расход' [Type], TouristTourID, [Name], Amount, [Date]
FROM Expense, FinanceType t
WHERE TypeID = t.ID AND [Date] BETWEEN @d1 AND @d2
GO

/*** 12 ***/
SELECT [Name], s1.Planes, CONCAT(CAST(s1.Planes AS real)/s2.Planes*100, '%') [Planes percentage],
	   s1.Places [Cargo places], CONCAT(CAST(s1.Places AS real)/s2.Places*100, '%') [Places percentage],
	   s1.[Weight], CONCAT(CAST(s1.[Weight] AS real)/s2.[Weight]*100, '%') [Weight percentage]
FROM (SELECT [Name], COUNT(DISTINCT CONCAT(PlaneID, [Date])) Planes, SUM(Places) Places, SUM([Weight]) [Weight]
	  FROM Cargo
	  GROUP BY [Name]) s1,
	 (SELECT COUNT(DISTINCT CONCAT(PlaneID, [Date])) Planes, SUM(Places) Places, SUM([Weight]) [Weight]
	  FROM Cargo) s2

/*** 13 ***/
SELECT CONCAT(Income/Expense*100, '%') Profitability
FROM (SELECT SUM(Amount) Income
	  FROM Income) s1,
	 (SELECT SUM(Amount) Expense
	  FROM Expense) s2

/*** 14 ***/
--все
SELECT CONCAT(CAST(s1.Quantity AS real)/s2.Quantity*100, '%') [Percentage]
FROM (SELECT COUNT(DISTINCT PassportID) Quantity
	  FROM TouristTour
	  WHERE dbo.get_tourist_type(PassportID) = 'Отдых') s1,
	 (SELECT COUNT(DISTINCT PassportID) Quantity
	  FROM TouristTour
	  WHERE dbo.get_tourist_type(PassportID) = 'Шопинг') s2
--за период
DECLARE @d1 date = '20210101'
DECLARE @d2 date = '20210430'
SELECT CONCAT(CAST(s1.Quantity AS real)/s2.Quantity*100, '%') [Percentage]
FROM (SELECT COUNT(DISTINCT PassportID) Quantity
	  FROM TouristTour
	  WHERE dbo.get_tourist_type(PassportID) = 'Отдых' AND [StartDate] BETWEEN @d1 AND @d2) s1,
	 (SELECT COUNT(DISTINCT PassportID) Quantity
	  FROM TouristTour
	  WHERE dbo.get_tourist_type(PassportID) = 'Шопинг' AND [StartDate] BETWEEN @d1 AND @d2) s2
GO

/*** 15 ***/
--рейс туда
SELECT tt.PassportID, Surname, t.[Name], Patronymic, h.[Name] Hotel
FROM TouristTour tt, Plane p, Tourist t, Hotel h
WHERE tt.StartPlaneID = p.ID AND tt.PassportID = t.PassportID AND HotelID = h.ID
	  AND p.[Name] = 'рейс1' AND [StartDate] = '20210402'
--рейс обратно
SELECT tt.PassportID, Surname, t.[Name], Patronymic, h.[Name] Hotel
FROM TouristTour tt, Plane p, Tourist t, Hotel h
WHERE tt.EndPlaneID = p.ID AND tt.PassportID = t.PassportID AND HotelID = h.ID
	  AND p.[Name] = 'рейс5' AND [EndDate] = '20210416'
--груз
SELECT PassportID, c.[Name], Places, [Weight]
FROM Cargo c, Plane p
WHERE p.[Name] = 'рейс5' AND [Date] = '20210416'