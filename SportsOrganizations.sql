--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'SportsOrganizationsDB'
GO
USE [master]
GO
ALTER DATABASE [SportsOrganizationsDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [SportsOrganizationsDB]
GO

-- 10 --
------------DATABASE------------
CREATE DATABASE [SportsOrganizationsDB]
GO

USE [SportsOrganizationsDB]
GO

CREATE TABLE [Construction]
(
	[ID] INT PRIMARY KEY IDENTITY,
	[Name] VARCHAR(50) UNIQUE NOT NULL,
	[Type] VARCHAR(10) NOT NULL CONSTRAINT Construction_Types CHECK ([Type] IN ('Спортзал', 'Манеж', 'Стадион', 'Корт'))
) 
GO

CREATE TABLE [Info]
(
	[ID] INT PRIMARY KEY IDENTITY,
	[ConstructionID] INT NOT NULL REFERENCES Construction (ID),
	[Type] VARCHAR(20) NOT NULL CONSTRAINT Info_Types CHECK ([Type] IN ('Вместимость', 'Тип покрытия', 'Площадь')),
	[Value] VARCHAR(50) NOT NULL
)
GO

CREATE TABLE [SportKind]
(
	[ID] INT PRIMARY KEY IDENTITY,
	[Kind] VARCHAR(50) UNIQUE NOT NULL
)
GO

CREATE TABLE [Coach]
(
	[ID] INT PRIMARY KEY IDENTITY,
	[FIO] VARCHAR(100) NOT NULL,
	[SportKindID] INT NOT NULL REFERENCES SportKind (ID)
)
GO

CREATE TABLE [Club]
(
	[ID] INT PRIMARY KEY IDENTITY,
	[Name] VARCHAR(50) UNIQUE NOT NULL
)
GO

CREATE TABLE [Sportsman]
(
	[ID] INT PRIMARY KEY IDENTITY,
	[FIO] VARCHAR(100) NOT NULL,
	[ClubID] INT NOT NULL REFERENCES Club (ID)
)
GO

CREATE TABLE [Category]
(
	[ID] INT PRIMARY KEY,
	[Name] VARCHAR(8) UNIQUE NOT NULL
)
GO

INSERT INTO [Category] VALUES
	(1, '3'),
	(2, '2'),
	(3, '1'),
	(4, 'КМС')
GO

CREATE TABLE [SportsmanCoach]
(
	[SportsmanID] INT NOT NULL REFERENCES Sportsman (ID),
	[CoachID] INT NOT NULL REFERENCES Coach (ID),
	PRIMARY KEY (SportsmanID, CoachID)
)
GO

CREATE TABLE [SportsmanCategory]
(
	[SportsmanID] INT NOT NULL REFERENCES Sportsman (ID),
	[SportKindID] INT NOT NULL REFERENCES SportKind (ID),
	[CategoryID] INT NOT NULL REFERENCES Category (ID),
	PRIMARY KEY (SportsmanID, SportKindID)
)
GO

CREATE TABLE [Competition]
(
	[ID] INT PRIMARY KEY IDENTITY,
	[Name] VARCHAR(100) NOT NULL,
	[Organizer] VARCHAR(50) NOT NULL,
	[SportKindID] INT NOT NULL REFERENCES SportKind (ID),
	[ConstructionID] INT NOT NULL REFERENCES Construction (ID),
	[StartDate] DATE NOT NULL,
	[EndDate] DATE NOT NULL,
	CONSTRAINT Competition_Dates CHECK (EndDate >= StartDate)
)
GO

CREATE TABLE [SportsmanCompetition]
(
	[SportsmanID] INT NOT NULL REFERENCES Sportsman (ID),
	[CompetitionID] INT NOT NULL REFERENCES Competition (ID),
	[Place] TINYINT NOT NULL CONSTRAINT SportsmanCompetition_Place CHECK (place > 0),
	PRIMARY KEY (SportsmanID, CompetitionID)
)
GO


------------QUERIES------------
----1----
--указанный тип
SELECT [Name]
FROM Construction
WHERE [Type] = 'стадион'
--указанные тип и характеристики
SELECT [Name], i.[Type], [Value]
FROM Construction c JOIN Info i ON c.ID = i.ConstructionID
WHERE c.[Type] = 'стадион' AND i.[Type] = 'вместимость' AND [Value] >= 30000

----2----
--указанный вид спорта
SELECT s.FIO
FROM Sportsman s JOIN SportsmanCategory sc ON s.ID = sc.SportsmanID
				 JOIN SportKind sk ON sc.SportKindID = sk.ID
WHERE Kind = 'хоккей'
--указанные вид и разряд
SELECT s.FIO, c.[Name] Category
FROM Sportsman s JOIN SportsmanCategory sc ON s.ID = sc.SportsmanID
				 JOIN SportKind sk ON sc.SportKindID = sk.ID
				 JOIN Category c ON sc.CategoryID = c.ID
WHERE Kind = 'хоккей' AND CategoryID >= (SELECT ID FROM Category WHERE [Name] = '2')

----3----
--указанный тренер
SELECT s.FIO
FROM Sportsman s JOIN SportsmanCoach sc ON s.ID = sc.SportsmanID
				 JOIN Coach c ON sc.CoachID = c.ID
WHERE c.FIO = 'беляев петр петрович'
--указанные тренер и разряд
SELECT s.FIO, cat.[Name]
FROM Sportsman s JOIN SportsmanCoach sc ON s.ID = sc.SportsmanID
				 JOIN Coach c ON sc.CoachID = c.ID
				 JOIN SportsmanCategory scat ON s.ID = scat.SportsmanID
				 JOIN Category cat ON scat.CategoryID = cat.ID
WHERE c.FIO = 'беляев петр петрович' AND cat.[Name] = 'кмс'

----4----
SELECT FIO, Kind
FROM Sportsman s JOIN SportsmanCategory sc ON s.ID = sc.SportsmanID
				 JOIN SportKind sk ON sc.SportKindID = sk.ID
WHERE s.ID IN (SELECT SportsmanID
			   FROM SportsmanCategory 
			   GROUP BY SportsmanID 
			   HAVING COUNT(SportKindID) > 1)

----5----
SELECT c.FIO
FROM Coach c JOIN SportsmanCoach sc ON sc.CoachID = c.ID
			 JOIN Sportsman s ON s.ID = sc.SportsmanID
WHERE s.FIO = 'петров петр петрович'

----6----
--указанный период
SELECT c.[Name], Organizer, Kind, co.[Name] Venue, StartDate, EndDate
FROM Competition c JOIN SportKind sk ON c.SportKindID = sk.ID
				   JOIN Construction co ON c.ConstructionID = co.ID
WHERE StartDate >= '20210101' AND EndDate <= '20210331'
--указанные период и организатор
SELECT c.[Name], Kind, co.[Name] Venue, StartDate, EndDate
FROM Competition c JOIN SportKind sk ON c.SportKindID = sk.ID
				   JOIN Construction co ON c.ConstructionID = co.ID
WHERE StartDate >= '20210101' AND EndDate <= '20210531' AND Organizer = 'оао газпром'

----7----
SELECT s.FIO, Place
FROM Sportsman s JOIN SportsmanCompetition sc ON s.ID = sc.SportsmanID
				 JOIN Competition c ON c.ID = sc.CompetitionID
WHERE [Name] = 'лига чемпионов' AND Place <= 3
ORDER BY Place

----8----
--указанное сооружение
SELECT c.[Name], Organizer, Kind, StartDate, EndDate
FROM Competition c JOIN SportKind sk ON c.SportKindID = sk.ID
				   JOIN Construction co ON c.ConstructionID = co.ID
WHERE co.[Name] = 'зенит арена'
--указанные сооружение и вид
SELECT c.[Name], Organizer, StartDate, EndDate
FROM Competition c JOIN SportKind sk ON c.SportKindID = sk.ID
				   JOIN Construction co ON c.ConstructionID = co.ID
WHERE co.[Name] = 'зенит арена' AND Kind = 'футбол'

----9----
SELECT c.[Name], COUNT(DISTINCT SportsmanID) Competitors
FROM Club c JOIN Sportsman s ON c.ID = s.ClubID
			JOIN SportsmanCompetition sc ON s.ID = sc.SportsmanID
			JOIN Competition co ON sc.CompetitionID = co.ID
WHERE StartDate >= '20210301' AND EndDate <= '20210531'
GROUP BY c.[Name]

----10----
SELECT FIO
FROM Coach c JOIN SportKind sk ON c.SportKindID = sk.ID
WHERE Kind = 'плавание'

----11----
SELECT FIO
FROM Sportsman s
WHERE s.ID NOT IN (SELECT SportsmanID 
				   FROM SportsmanCompetition sc JOIN Competition co ON sc.CompetitionID = co.ID
				   WHERE StartDate >= '20210301' AND EndDate <= '20210531')

----12----
SELECT Organizer, COUNT(Organizer) [Count]
FROM Competition 
WHERE StartDate >= '20210301' AND EndDate <= '20210531'
GROUP BY Organizer

----13----
SELECT c.[Name], StartDate, EndDate
FROM Construction c JOIN Competition co ON c.ID = co.ConstructionID
WHERE StartDate >= '20210301' AND EndDate <= '20210531'
ORDER BY c.[Name], StartDate