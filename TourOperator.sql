/* предполагается, что список туристов всякий раз формируется заново, т.е. не хранит историю. 
** в противном случае возникнет проблема нескольких категорий туриста (если турист некогда был 
** в одной категории, а ныне в другой, в результатах запросов будут записи для каждой). 
** поэтому туриста нельзя определить в две категории одновременно.

** использование суррогатного ключа в списке туристов приведет к потере истории клиентов,
** если нет таблицы соответствий ID и паспортов. 

** тип туриста в таблице Tour не является избыточной информацией, он хранит историю,
** тогда как TypeID в таблице Tourist хранит текущий (последний) тип. */

CREATE DATABASE [TourOperatorDB]
GO

USE [TourOperatorDB]
GO

CREATE TABLE [TouristType](
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(20) UNIQUE NOT NULL
) 
GO

INSERT INTO TouristType ([Name]) VALUES 
	('Отдых'), 
	('Шопинг'),
	('Отдых Ребенок'), 
	('Шопинг Ребенок')
GO

CREATE TABLE [Tourist](
	[PassportID] bigint PRIMARY KEY,
	[TypeID] tinyint NOT NULL REFERENCES [TouristType] (ID)
) 
GO

CREATE FUNCTION dbo.get_tourist_type(@PassportID bigint) RETURNS varchar(20) AS
BEGIN
	RETURN (SELECT [Name]
			FROM TouristType, Tourist
			WHERE @PassportID = PassportID AND TypeID = ID)
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

CREATE TABLE [RestTourist](
	[PassportID] bigint PRIMARY KEY REFERENCES [Tourist] (PassportID) ON DELETE CASCADE,
	[Surname] varchar(50) NOT NULL,
	[Name] varchar(50) NOT NULL,
	[Patronymic] varchar(50) NOT NULL,
	[Sex] char(1) NOT NULL CONSTRAINT CK_RestTourist_Sex CHECK (Sex IN ('М', 'Ж')),
	[Birthday] date NOT NULL CONSTRAINT CK_RestTourist_Birthday CHECK (dbo.get_age(Birthday) >= 18),
	--атрибуты
	CONSTRAINT CK_RestTourist_Type CHECK (dbo.get_tourist_type(PassportID) = 'Отдых')
) 
GO

CREATE TABLE [ShopTourist](
	[PassportID] bigint PRIMARY KEY REFERENCES [Tourist] (PassportID) ON DELETE CASCADE,
	[Surname] varchar(50) NOT NULL,
	[Name] varchar(50) NOT NULL,
	[Patronymic] varchar(50) NOT NULL,
	[Sex] char(1) NOT NULL CONSTRAINT CK_ShopTourist_Sex CHECK (Sex IN ('М', 'Ж')),
	[Birthday] date NOT NULL CONSTRAINT CK_ShopTourist_Birthday CHECK (dbo.get_age(Birthday) >= 18),
	--атрибуты
	CONSTRAINT CK_ShopTourist_Type CHECK (dbo.get_tourist_type(PassportID) = 'Шопинг')
) 
GO

CREATE FUNCTION check_rest_tourist(@PassportID bigint) RETURNS bit AS
BEGIN
	IF EXISTS (SELECT PassportID 
			   FROM RestTourist 
			   WHERE PassportID = @PassportID)
		RETURN 1
	RETURN 0
END
GO

CREATE FUNCTION check_shop_tourist(@PassportID bigint) RETURNS bit AS
BEGIN
	IF EXISTS (SELECT PassportID 
			   FROM ShopTourist 
			   WHERE PassportID = @PassportID)
		RETURN 1
	RETURN 0
END
GO

ALTER TABLE [RestTourist]
ADD CONSTRAINT CK_RestTourist_Exists CHECK (dbo.check_shop_tourist(PassportID) = 0)
GO

ALTER TABLE [ShopTourist]
ADD CONSTRAINT CK_ShopTourist_Exists CHECK (dbo.check_rest_tourist(PassportID) = 0)
GO

CREATE TABLE [RestChild](
	[PassportID] bigint PRIMARY KEY REFERENCES [Tourist] (PassportID) ON DELETE CASCADE,
	[Surname] varchar(50) NOT NULL,
	[Name] varchar(50) NOT NULL,
	[Patronymic] varchar(50) NOT NULL,
	[Sex] char(1) NOT NULL CONSTRAINT CK_RestChild_Sex CHECK (Sex IN ('М', 'Ж')),
	[Birthday] date NOT NULL CONSTRAINT CK_RestChild_Birthday CHECK (dbo.get_age(Birthday) < 18),
	[Parent1ID] bigint NULL REFERENCES [RestTourist] (PassportID),
	[Parent2ID] bigint NULL REFERENCES [RestTourist] (PassportID),
	--атрибуты
	CONSTRAINT CK_RestChild_Type CHECK (dbo.get_tourist_type(PassportID) = 'Отдых Ребенок'),
	CONSTRAINT CK_RestChild_Parents CHECK (CASE WHEN Parent1ID IS NULL THEN 0 ELSE 1 END + 
										   CASE WHEN Parent2ID IS NULL THEN 0 ELSE 1 END >= 1
										   AND Parent1ID != Parent2ID)
) 
GO

CREATE TABLE [ShopChild](
	[PassportID] bigint PRIMARY KEY REFERENCES [Tourist] (PassportID) ON DELETE CASCADE,
	[Surname] varchar(50) NOT NULL,
	[Name] varchar(50) NOT NULL,
	[Patronymic] varchar(50) NOT NULL,
	[Sex] char(1) NOT NULL CONSTRAINT CK_ShopChild_Sex CHECK (Sex IN ('М', 'Ж')),
	[Birthday] date NOT NULL CONSTRAINT CK_ShopChild_Birthday CHECK (dbo.get_age(Birthday) < 18),
	[Parent1ID] bigint NULL REFERENCES [ShopTourist] (PassportID),
	[Parent2ID] bigint NULL REFERENCES [ShopTourist] (PassportID),
	--атрибуты
	CONSTRAINT CK_ShopChild_Type CHECK (dbo.get_tourist_type(PassportID) = 'Шопинг Ребенок'),
	CONSTRAINT CK_ShopChild_Parents CHECK (CASE WHEN Parent1ID IS NULL THEN 0 ELSE 1 END + 
										   CASE WHEN Parent2ID IS NULL THEN 0 ELSE 1 END >= 1
										   AND Parent1ID != Parent2ID)
) 
GO

CREATE VIEW TouristList AS
	SELECT PassportID, Surname, [Name], Patronymic, Sex, Birthday, 'Отдых' [Type]
	FROM RestTourist
	UNION ALL
	SELECT PassportID, Surname, [Name], Patronymic, Sex, Birthday, 'Шопинг' [Type]
	FROM ShopTourist	
GO

CREATE VIEW ChildList AS
	SELECT PassportID, Surname, [Name], Patronymic, Sex, Birthday, Parent1ID, Parent2ID, 'Отдых Ребенок' [Type]
	FROM RestChild
	UNION ALL
	SELECT PassportID, Surname, [Name], Patronymic, Sex, Birthday, Parent1ID, Parent2ID, 'Шопинг Ребенок' [Type]
	FROM ShopChild
GO

CREATE VIEW TouristAll AS
	SELECT *
	FROM TouristList
	UNION ALL
	SELECT PassportID, Surname, [Name], Patronymic, Sex, Birthday, [Type]
	FROM ChildList
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

CREATE FUNCTION check_excursion(@PassportID bigint, @ExcursionID int, @Date date) RETURNS bit AS
BEGIN
	IF dbo.get_tourist_type(@PassportID) LIKE '%Ребенок'
	BEGIN
		DECLARE @p1 bigint, @p2 bigint, @e int, @d date
		SELECT @p1 = Parent1ID, @p2 = Parent2ID
		FROM ChildList
		WHERE PassportID = @PassportID
		IF @p1 IS NOT NULL 
		BEGIN
			SELECT @e = ExcursionID, @d = [Date]
			FROM Schedule
			WHERE PassportID = @p1
			IF @ExcursionID = @e AND @Date = @d
				RETURN 0
		END
		IF @p2 IS NOT NULL
		BEGIN
			SELECT @e = ExcursionID, @d = [Date]
			FROM Schedule
			WHERE PassportID = @p2
			IF @ExcursionID = @e AND @Date = @d
				RETURN 0
		END
		RETURN 1
	END
	RETURN 0
END
GO

CREATE FUNCTION check_date(@PassportID bigint, @Date date) RETURNS bit AS
BEGIN
	DECLARE @d1 date, @d2 date
	SELECT @d1 = StartDate, @d2 = EndDate
	FROM Tour
	WHERE PassportID = @PassportID AND StartDate = (SELECT MAX(StartDate)
													FROM Tour
													WHERE PassportID = @PassportID)
								   AND EndDate = (SELECT MAX(EndDate)
												  FROM Tour
												  WHERE PassportID = @PassportID)
	IF @Date BETWEEN @d1 AND @d2
		RETURN 0
	RETURN 1
END
GO

CREATE TABLE [Schedule](
	[ID] int PRIMARY KEY IDENTITY,
	[PassportID] bigint NOT NULL REFERENCES [Tourist] (PassportID)
		CONSTRAINT CK_Schedule_PassportID_Type CHECK (dbo.get_tourist_type(PassportID) LIKE 'Отдых%'),
	[ExcursionID] int NOT NULL REFERENCES [Excursion] (ID),
	[Date] date NOT NULL,
	CONSTRAINT CK_Schedule_Date CHECK (dbo.check_date(PassportID, [Date]) = 0),
	CONSTRAINT CK_Schedule_Excursion_SameAsParents CHECK (dbo.check_excursion(PassportID, ExcursionID, [Date]) = 0)
) 
GO

CREATE TABLE [PlaneType](
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(20) UNIQUE NOT NULL
) 
GO

INSERT INTO PlaneType ([Name]) VALUES 
	('Пассажирский'), 
	('Грузопассажирский'),
	('Грузовой')
GO

CREATE FUNCTION check_cargo_plane(@ID int, @IsStartPlane bit) RETURNS bit AS
BEGIN
	IF dbo.get_plane_type(@ID) = 'Грузовой'
	BEGIN
		IF @IsStartPlane = 0
			RETURN 0
		RETURN 1
	END
	RETURN 0
END
GO

CREATE TABLE [Plane](
	[ID] int PRIMARY KEY IDENTITY,
	[TypeID] tinyint NOT NULL REFERENCES PlaneType (ID),
	[Name] varchar(50) NOT NULL,
	[IsStartPlane] bit NOT NULL,
	[Price] money NOT NULL,
	CONSTRAINT CK_Plane_IsStartPlane_Cargo CHECK (dbo.check_cargo_plane(ID, IsStartPlane) = 0)
) 
GO

CREATE FUNCTION get_plane_type(@ID int) RETURNS varchar(20) AS
BEGIN
	RETURN (SELECT t.[Name]
			FROM PlaneType t, Plane p
			WHERE @ID = p.ID AND TypeID = t.ID)
END
GO

CREATE FUNCTION check_plane(@ID int) RETURNS bit AS
BEGIN
	RETURN (SELECT IsStartPlane
			FROM Plane
			WHERE @ID = ID)
END
GO

CREATE TABLE [Hotel](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[Price] money NOT NULL
) 
GO

/* если родитель некогда прилетал и в последний раз останавливался в проверяемом отеле,
** а сейчас информацию о его новом полёте не внесли (или он вообще не летит), то функция не найдёт ошибку.
** эту проблему нельзя исправить, так как невозможно связать родителей и детей по датам (например, сначала 
** прилетел родитель с ребенком, затем прилетел второй, улетел первый, и позже улетел второй с ребенком).
** в таблицу всегда сначала первый родитель, потом его дети */
CREATE FUNCTION check_hotel(@PassportID bigint, @HotelID int) RETURNS bit AS
BEGIN
	IF dbo.get_tourist_type(@PassportID) LIKE '%Ребенок'
	BEGIN
		DECLARE @p1 bigint, @p2 bigint
		SELECT @p1 = Parent1ID, @p2 = Parent2ID
		FROM ChildList
		WHERE PassportID = @PassportID
		IF @p1 IS NOT NULL AND @HotelID = (SELECT HotelID
										   FROM Tour
										   WHERE PassportID = @p1 AND StartDate = (SELECT MAX(StartDate)
																				   FROM Tour
																				   WHERE PassportID = @p1))
			RETURN 0
		IF @p2 IS NOT NULL AND @HotelID = (SELECT HotelID
										   FROM Tour
										   WHERE PassportID = @p2 AND StartDate = (SELECT MAX(StartDate)
																				   FROM Tour
																				   WHERE PassportID = @p2))
			RETURN 0
		RETURN 1
	END
	RETURN 0
END
GO

CREATE TABLE [Tour](
	[ID] int PRIMARY KEY IDENTITY,
	[PassportID] bigint NOT NULL REFERENCES [Tourist] (PassportID),
	[Type] AS dbo.get_tourist_type(PassportID),
	[StartDate] date NOT NULL,
	[StartPlaneID] int NOT NULL REFERENCES [Plane] (ID) 
		CONSTRAINT CK_Tour_StartPlane_Check CHECK (dbo.check_plane(StartPlaneID) = 1),
	[EndDate] date NOT NULL,
	[EndPlaneID] int NOT NULL REFERENCES [Plane] (ID)
		CONSTRAINT CK_Tour_EndPlane_Check CHECK (dbo.check_plane(EndPlaneID) = 0),
	[HotelID] int NOT NULL REFERENCES [Hotel] (ID),
	CONSTRAINT CK_Tour_StartPlane_Type CHECK (dbo.get_plane_type(StartPlaneID) IN ('Пассажирский', 'Грузопассажирский')),
	CONSTRAINT CK_Tour_EndPlane_Type CHECK (dbo.get_plane_type(EndPlaneID) IN ('Пассажирский', 'Грузопассажирский')),
	CONSTRAINT CK_Tour_Hotel_SameAsParents CHECK (dbo.check_hotel(PassportID, HotelID) = 0),
	CONSTRAINT CK_Tour_EndDate CHECK (EndDate >= StartDate)
) 
GO

CREATE TABLE [Cargo](
	[ID] int PRIMARY KEY IDENTITY,
	[PassportID] bigint NOT NULL REFERENCES [Tourist] (PassportID)
		CONSTRAINT CK_Cargo_PassportID_Type CHECK (dbo.get_tourist_type(PassportID) LIKE 'Шопинг%'),
	[Name] varchar(50) NOT NULL,
	[Date] date NOT NULL,
	[PlaneID] int NOT NULL REFERENCES [Plane] (ID)
		CONSTRAINT CK_Cargo_Plane_Type CHECK (dbo.get_plane_type(PlaneID) IN ('Грузовой', 'Грузопассажирский')),
	[Places] int NOT NULL,
	[Weight] int NOT NULL,
	[PackingCost] money NOT NULL,
	[InsuranceCost] money NOT NULL,
	[Total] AS PackingCost + InsuranceCost,
	CONSTRAINT CK_Cargo_Plane_Check CHECK (dbo.check_plane(PlaneID) = 0)
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

CREATE FUNCTION check_finance_type(@TourID int, @TypeID tinyint) RETURNS bit AS
BEGIN
	DECLARE @t1 varchar(20) = (SELECT [Type]
							   FROM Tour
							   WHERE @TourID = ID)
	DECLARE @t2 varchar(50) = (SELECT [Name]
							   FROM FinanceType
							   WHERE @TypeID = ID)
	IF @t1 LIKE 'Отдых%' AND @t2 = 'Хранение груза'
		RETURN 1
	IF @t1 LIKE 'Шопинг%' AND @t2 = 'Экскурсия'
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE [Income](
	[ID] int PRIMARY KEY IDENTITY,
	[TourID] int NOT NULL REFERENCES [Tour] (ID),
	[TypeID] tinyint NOT NULL REFERENCES [FinanceType] (ID),
	[Amount] money NOT NULL,
	[Date] date NOT NULL,
	CONSTRAINT CK_Income_Type CHECK (dbo.check_finance_type(TourID, TypeID) = 0)
) 
GO

CREATE TABLE [Expense](
	[ID] int PRIMARY KEY IDENTITY,
	[TourID] int NOT NULL REFERENCES [Tour] (ID),
	[TypeID] tinyint NOT NULL REFERENCES [FinanceType] (ID),
	[Amount] money NOT NULL,
	[Date] date NOT NULL,
	CONSTRAINT CK_Expense_Type CHECK (dbo.check_finance_type(TourID, TypeID) = 0)
) 
GO

/*** ЗАПРОСЫ ***/

/*** 1 ***/

--все
SELECT *
FROM TouristAll

--указанной категории
SELECT *
FROM TouristAll
WHERE [Type] LIKE 'Отдых%'

/*** 2 ***/

--указанная гостиница
SELECT DISTINCT a.*
FROM TouristAll a, Tour t, Hotel h
WHERE a.PassportID = t.PassportID AND t.HotelID = h.ID AND h.[Name] = 'no-tell'

--указанные гостиница и категория
SELECT DISTINCT a.*
FROM TouristAll a, Tour t, Hotel h
WHERE a.PassportID = t.PassportID AND t.HotelID = h.ID AND h.[Name] = 'no-tell' AND a.[Type] LIKE 'Отдых%'

/*** 3 ***/

--все
SELECT COUNT(DISTINCT PassportID) Quantity
FROM Tour
WHERE StartDate BETWEEN '20200101' AND '20210515'

--указанной категории
SELECT COUNT(DISTINCT PassportID) Quantity
FROM Tour
WHERE StartDate BETWEEN '20200101' AND '20210515' AND [Type] LIKE 'Отдых%'

/*** 4 ***/

--количество посещений
SELECT COUNT(PassportID) [Visit count]
FROM Tour
WHERE PassportID = 32165446

--даты посещений, отели
SELECT StartDate, EndDate, [Name] Hotel
FROM Tour, Hotel
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
			 FROM Tour t, (SELECT PassportID, MAX(EndDate) [Date]
						   FROM Tour
						   WHERE EndDate >= GETDATE()
						   GROUP BY PassportID) s1
			 WHERE t.PassportID = s1.PassportID AND t.EndDate = s1.[Date]) sub
WHERE HotelID = ID
GROUP BY [Name]

--количество человек за период
SELECT [Name], COUNT(HotelID) Quantity
FROM Hotel, (SELECT DISTINCT PassportID, HotelID
			 FROM Tour
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
FROM Tour, Plane p
WHERE p.ID = StartPlaneID AND [Name] = 'рейс1' AND StartDate = '20210402'

--рейс обратно, занятые места
SELECT COUNT(EndPlaneID) [Places occupied]
FROM Tour, Plane p
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
SELECT 'Доход' [Type], TourID, [Name], Amount, [Date]
FROM Income, FinanceType t
WHERE TypeID = t.ID
UNION ALL
SELECT 'Расход' [Type], TourID, [Name], Amount, [Date]
FROM Expense, FinanceType t
WHERE TypeID = t.ID

--указанной категории
DECLARE @t varchar(20) = 'Шопинг%'
SELECT 'Доход' [Type], TourID, [Name], Amount, [Date]
FROM Income, FinanceType t, Tour 
WHERE TypeID = t.ID AND TourID = Tour.ID AND [Type] LIKE @t
UNION ALL
SELECT 'Расход' [Type], TourID, [Name], Amount, [Date]
FROM Expense, FinanceType t, Tour 
WHERE TypeID = t.ID AND TourID = Tour.ID AND [Type] LIKE @t
GO

/*** 11 ***/

DECLARE @d1 date = '20210101'
DECLARE @d2 date = '20210430'
SELECT 'Доход' [Type], TourID, [Name], Amount, [Date]
FROM Income, FinanceType t
WHERE TypeID = t.ID AND [Date] BETWEEN @d1 AND @d2
UNION ALL
SELECT 'Расход' [Type], TourID, [Name], Amount, [Date]
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
	  FROM Tour
	  WHERE [Type] LIKE 'Отдых%') s1,
	 (SELECT COUNT(DISTINCT PassportID) Quantity
	  FROM Tour
	  WHERE [Type] LIKE 'Шопинг%') s2

--за период
DECLARE @d1 date = '20210101'
DECLARE @d2 date = '20210430'
SELECT CONCAT(CAST(s1.Quantity AS real)/s2.Quantity*100, '%') [Percentage]
FROM (SELECT COUNT(DISTINCT PassportID) Quantity
	  FROM Tour
	  WHERE [Type] LIKE 'Отдых%' AND [StartDate] BETWEEN @d1 AND @d2) s1,
	 (SELECT COUNT(DISTINCT PassportID) Quantity
	  FROM Tour
	  WHERE [Type] LIKE 'Шопинг%' AND [StartDate] BETWEEN @d1 AND @d2) s2
GO

/*** 15 ***/

--рейс туда
SELECT t.PassportID, Surname, a.[Name], Patronymic, h.[Name] Hotel
FROM Tour t, Plane p, TouristAll a, Hotel h
WHERE t.StartPlaneID = p.ID AND t.PassportID = a.PassportID AND HotelID = h.ID
	  AND p.[Name] = 'рейс1' AND [StartDate] = '20210402'

--рейс обратно
SELECT t.PassportID, Surname, a.[Name], Patronymic, h.[Name] Hotel
FROM Tour t, Plane p, TouristAll a, Hotel h
WHERE t.EndPlaneID = p.ID AND t.PassportID = a.PassportID AND HotelID = h.ID
	  AND p.[Name] = 'рейс5' AND [EndDate] = '20210416'

--груз
SELECT PassportID, c.[Name], Places, [Weight]
FROM Cargo c, Plane p
WHERE p.[Name] = 'рейс5' AND [Date] = '20210416'