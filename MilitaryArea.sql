--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'MilitaryAreaDB'
GO
USE [master]
GO
ALTER DATABASE [MilitaryAreaDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [MilitaryAreaDB]
GO

-- 7 --
--Create DB
CREATE DATABASE [MilitaryAreaDB]
GO

USE [MilitaryAreaDB]
GO

CREATE FUNCTION IsOfficer(@ID int) RETURNS bit AS
BEGIN
	RETURN (SELECT IsOfficer 
			FROM Personnel p, [Rank] r
			WHERE p.ID = @ID AND r.ID = p.RankID)
END
GO

CREATE TABLE [Army](
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[CommanderID] int NOT NULL CONSTRAINT CK_Army_Commander_Rank CHECK (dbo.IsOfficer(CommanderID) = 1)
) 
GO

CREATE TABLE [Formation](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[ArmyID] tinyint NOT NULL REFERENCES Army (ID),
	[CommanderID] int NOT NULL CONSTRAINT CK_Formation_Commander_Rank CHECK (dbo.IsOfficer(CommanderID) = 1)
) 
GO

CREATE TABLE [Unit](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[FormationID] int NOT NULL REFERENCES Formation (ID),
	[CommanderID] int NOT NULL CONSTRAINT CK_Unit_Commander_Rank CHECK (dbo.IsOfficer(CommanderID) = 1),
	[Dislocation] varchar(50) NOT NULL
) 
GO

CREATE TABLE [Building](
	[ID] int PRIMARY KEY IDENTITY,
	[IsResidential] bit NOT NULL,
	[UnitID] int NOT NULL REFERENCES Unit (ID)
) 
GO

CREATE FUNCTION check_building(@ID int) RETURNS bit AS
BEGIN
	DECLARE @r bit = (SELECT IsResidential 
					  FROM Building b, Company c
					  WHERE b.ID = @ID AND c.UnitID = b.UnitID 
					  GROUP BY IsResidential)
	IF @r IS NULL
		SET @r = 0
	RETURN @r
END
GO

CREATE TABLE [Company](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[UnitID] int NOT NULL REFERENCES Unit (ID),
	[CommanderID] int NOT NULL CONSTRAINT CK_Company_Commander_Rank CHECK (dbo.IsOfficer(CommanderID) = 1),
	[BuildingID] int NOT NULL REFERENCES Building (ID) CONSTRAINT CK_Company_BuildingID CHECK (dbo.check_building(BuildingID) = 1)
) 
GO

CREATE TABLE [Platoon](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[CompanyID] int NOT NULL REFERENCES Company (ID),
	[CommanderID] int NOT NULL
) 
GO

CREATE TABLE [Squad](
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[PlatoonID] int NOT NULL REFERENCES Platoon (ID),
	[CommanderID] int NOT NULL
) 
GO

CREATE TABLE [Rank](
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[IsOfficer] bit NOT NULL,
	[Rating] tinyint NOT NULL
)
GO

CREATE TABLE [Speciality](
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
) 
GO

CREATE TABLE [Personnel](
	[ID] int PRIMARY KEY IDENTITY,
	[Surname] varchar(50) NOT NULL,
	[Name] varchar(50) NOT NULL,
	[Patronymic] varchar(50) NOT NULL,
	[RankID] tinyint NOT NULL REFERENCES [Rank] (ID),
	[SpecialityID] tinyint NOT NULL REFERENCES [Speciality] (ID),
	[ArmyID] tinyint REFERENCES Army (ID),
	[FormationID] int REFERENCES Formation (ID),
	[UnitID] int REFERENCES Unit (ID),
	[CompanyID] int REFERENCES Company (ID),
	[PlatoonID] int REFERENCES Platoon (ID),
	[SquadID] int REFERENCES Squad (ID),
	[Additional] varchar(50) NULL
) 
GO

ALTER TABLE [Army]
ADD CONSTRAINT FK_Army_CommanderID FOREIGN KEY (CommanderID) REFERENCES Personnel (ID)
GO

ALTER TABLE [Formation]
ADD CONSTRAINT FK_Formation_CommanderID FOREIGN KEY (CommanderID) REFERENCES Personnel (ID)
GO

ALTER TABLE [Unit]
ADD CONSTRAINT FK_Unit_CommanderID FOREIGN KEY (CommanderID) REFERENCES Personnel (ID)
GO

ALTER TABLE [Company]
ADD CONSTRAINT FK_Company_CommanderID FOREIGN KEY (CommanderID) REFERENCES Personnel (ID)
GO

ALTER TABLE [Platoon]
ADD CONSTRAINT FK_Platoon_CommanderID FOREIGN KEY (CommanderID) REFERENCES Personnel (ID)
GO

ALTER TABLE [Squad]
ADD CONSTRAINT FK_Squad_CommanderID FOREIGN KEY (CommanderID) REFERENCES Personnel (ID)
GO

CREATE TABLE [Weaponry](
	[ID] int PRIMARY KEY IDENTITY,
	[Type] varchar(50) NOT NULL,
	[Quantity] int NOT NULL,
	[UnitID] int NOT NULL REFERENCES Unit (ID),
	[Additional] varchar(50) NULL
) 
GO

CREATE TABLE [Vehicle](
	[ID] int PRIMARY KEY IDENTITY,
	[Model] varchar(50) NOT NULL,
	[Quantity] int NOT NULL,
	[UnitID] int NOT NULL REFERENCES Unit (ID),
	[Additional] varchar(50) NULL
) 
GO

/* --- QUERIES --- */
/* --- 1 --- */
--1.1 military area
SELECT Unit.[Name], Surname + ' ' + p.[Name] + ' ' + Patronymic Commander
FROM Unit, Personnel p
WHERE CommanderID = p.ID
--1.2 army
SELECT u.[Name], Surname + ' ' + p.[Name] + ' ' + Patronymic Commander
FROM Unit u, Personnel p, Army a, Formation f
WHERE u.CommanderID = p.ID AND u.FormationID = f.ID AND f.ArmyID = a.ID AND a.[Name] = 'первая'
--1.3 formation
SELECT u.[Name], Surname + ' ' + p.[Name] + ' ' + Patronymic Commander
FROM Unit u, Personnel p, Formation f
WHERE u.CommanderID = p.ID AND u.FormationID = f.ID AND f.[Name] = 'дивизия'

/* --- 2 --- */
--2.1 all
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r
WHERE RankID = r.ID AND IsOfficer = 1
--2.2 defined rank, military area
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r
WHERE RankID = r.ID AND IsOfficer = 1 AND r.[Name] = 'генерал'
--2.3 defined rank, army
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r, Army a
WHERE RankID = r.ID AND IsOfficer = 1 AND r.[Name] = 'полковник' AND ArmyID = a.ID AND a.[Name] = 'третья'
--2.4 defined rank, formation
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r, Formation f
WHERE RankID = r.ID AND IsOfficer = 1 AND r.[Name] = 'генерал' AND FormationID = f.ID AND f.[Name] = 'корпус'
--2.5 defined rank, unit
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r, Unit u
WHERE RankID = r.ID AND IsOfficer = 1 AND r.[Name] = 'полковник' AND UnitID = u.ID AND u.[Name] = 'часть 1'

/* --- 3 --- */
--3.1 all
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r
WHERE RankID = r.ID AND IsOfficer = 0
--3.2 defined rank, military area
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r
WHERE RankID = r.ID AND IsOfficer = 0 AND r.[Name] = 'сержант'
--3.3 defined rank, army
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r, Army a
WHERE RankID = r.ID AND IsOfficer = 0 AND r.[Name] = 'сержант' AND ArmyID = a.ID AND a.[Name] = 'первая'
--3.4 defined rank, formation
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r, Formation f
WHERE RankID = r.ID AND IsOfficer = 0 AND r.[Name] = 'рядовой' AND FormationID = f.ID AND f.[Name] = 'дивизия'
--3.5 defined rank, unit
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r, Unit u
WHERE RankID = r.ID AND IsOfficer = 0 AND r.[Name] = 'сержант' AND UnitID = u.ID AND u.[Name] = 'часть 1'

/* --- 4 --- */
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic [Name], r.[Name] [Rank]
FROM Personnel p, [Rank] r, (SELECT Rating, UnitID
							 FROM Personnel p, [Rank] r 
							 WHERE r.ID = RankID AND Surname + ' ' + p.[Name] + ' ' + Patronymic = 'иванов иван иванович') sub
WHERE r.ID = RankID AND r.Rating > sub.Rating AND p.UnitID = sub.UnitID
ORDER BY r.Rating, Surname, p.[Name], Patronymic

/* --- 5 --- */
--5.1 military area
SELECT [Name], Dislocation
FROM Unit
--5.2 army
SELECT u.[Name], Dislocation
FROM Unit u, Army a, Formation f
WHERE u.FormationID = f.ID AND f.ArmyID = a.ID AND a.[Name] = 'третья'
--5.3 formation
SELECT u.[Name], Dislocation
FROM Unit u, Formation f
WHERE u.FormationID = f.ID AND f.[Name] = 'корпус'
--5.4 unit
SELECT [Name], Dislocation
FROM Unit
WHERE [Name] = 'часть 1'

/* --- 6 --- */
--6.1 all
SELECT Model, Quantity, [Name] Unit, Additional
FROM Vehicle, Unit u
WHERE u.ID = UnitID
--6.2 defined model, military area
SELECT Model, Quantity, [Name] Unit, Additional
FROM Vehicle, Unit u
WHERE u.ID = UnitID AND Model = 'Т-90'
--6.3 defined model, army
SELECT Model, Quantity, u.[Name] Unit, Additional
FROM Vehicle, Unit u, Army a, Formation f
WHERE u.ID = UnitID AND Model = 'Т-90' AND u.FormationID = f.ID AND f.ArmyID = a.ID AND a.[Name] = 'первая'
--6.4 defined model, formation
SELECT Model, Quantity, u.[Name] Unit, Additional
FROM Vehicle, Unit u, Formation f
WHERE u.ID = UnitID AND Model = 'Т-90' AND u.FormationID = f.ID AND f.[Name] = 'дивизия'
--6.5 all, unit
SELECT Model, Quantity, [Name] Unit, Additional
FROM Vehicle, Unit u
WHERE u.ID = UnitID AND u.[Name] = 'часть 1'

/* --- 7 --- */
--7.1 unit
SELECT [Name] Unit, b.ID Building, IsResidential
FROM Building b, Unit u
WHERE u.ID = UnitID AND [Name] = 'часть 1'
--7.2 >1 company
SELECT b.ID Building, COUNT(BuildingID) Companies
FROM Building b JOIN Company c ON BuildingID = b.ID
GROUP BY b.ID, BuildingID
HAVING COUNT(BuildingID) > 1
--7.3 no companies
SELECT u.[Name] Unit, b.ID Building, IsResidential
FROM Building b, Unit u
WHERE u.ID = b.UnitID
EXCEPT
SELECT u.[Name] Unit, b.ID Building, IsResidential
FROM Building b, Unit u, Company c
WHERE u.ID = b.UnitID AND b.ID = BuildingID

/* --- 8 --- */
--8.1 quantity > 5
SELECT [Name] Unit, Model, Quantity, Additional
FROM Unit u, Vehicle
WHERE u.ID = UnitID AND Quantity > 5 AND Model = 'т-90'
--8.2 no such model
SELECT [Name] Unit
FROM Unit u
EXCEPT
SELECT [Name] Unit
FROM Unit u, Vehicle
WHERE u.ID = UnitID AND Model = 'т-90'

/* --- 9 --- */
--9.1 all
SELECT [Type], Quantity, [Name] Unit, Additional
FROM Weaponry, Unit u
WHERE u.ID = UnitID
--9.2 defined type, military area
SELECT [Type], Quantity, [Name] Unit, Additional
FROM Weaponry, Unit u
WHERE u.ID = UnitID AND [Type] = 'пм'
--9.3 defined type, army
SELECT [Type], Quantity, u.[Name] Unit, Additional
FROM Weaponry, Unit u, Army a, Formation f
WHERE u.ID = UnitID AND [Type] = 'пм' AND u.FormationID = f.ID AND f.ArmyID = a.ID AND a.[Name] = 'третья'
--9.4 defined type, formation
SELECT [Type], Quantity, u.[Name] Unit, Additional
FROM Weaponry, Unit u, Formation f
WHERE u.ID = UnitID AND [Type] = 'пм' AND u.FormationID = f.ID AND f.[Name] = 'корпус'
--9.5 all, unit
SELECT [Type], Quantity, [Name] Unit, Additional
FROM Weaponry, Unit u
WHERE u.ID = UnitID AND u.[Name] = 'часть 88463'

/* --- 10 --- */
--10.1 all
SELECT s.[Name], COUNT(SpecialityID) Specialists
FROM Personnel p JOIN Speciality s ON SpecialityID = s.ID
GROUP BY s.[Name]
HAVING COUNT(SpecialityID) > 5
--10.2 army
SELECT s.[Name], COUNT(SpecialityID) Specialists
FROM Personnel p JOIN Speciality s ON SpecialityID = s.ID, Army a
WHERE p.ArmyID = a.ID AND a.[Name] = 'пятая'
GROUP BY s.[Name]
HAVING COUNT(SpecialityID) > 1
--10.3 formation
SELECT s.[Name], COUNT(SpecialityID) Specialists
FROM Personnel p JOIN Speciality s ON SpecialityID = s.ID, Formation f
WHERE p.FormationID = f.ID AND f.[Name] = 'дивизия'
GROUP BY s.[Name]
HAVING COUNT(SpecialityID) > 1
--10.4 unit
SELECT s.[Name], COUNT(SpecialityID) Specialists
FROM Personnel p JOIN Speciality s ON SpecialityID = s.ID, Unit u
WHERE p.UnitID = u.ID AND u.[Name] = 'часть 23248'
GROUP BY s.[Name]
HAVING COUNT(SpecialityID) > 1

/* --- 11 --- */
--11.1 all
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic Soldier, s.[Name]
FROM Personnel p, Speciality s
WHERE SpecialityID = s.ID AND s.[Name] = 'водитель'
--11.2 army
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic Soldier, s.[Name]
FROM Personnel p, Speciality s, Army a
WHERE SpecialityID = s.ID AND s.[Name] = 'водитель' AND p.ArmyID = a.ID AND a.[Name] = 'пятая'
--11.3 formation
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic Soldier, s.[Name]
FROM Personnel p, Speciality s, Formation f
WHERE SpecialityID = s.ID AND s.[Name] = 'водитель' AND p.FormationID = f.ID AND f.[Name] = 'корпус'
--11.4 unit
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic Soldier, s.[Name]
FROM Personnel p, Speciality s, Unit u
WHERE SpecialityID = s.ID AND s.[Name] = 'водитель' AND p.UnitID = u.ID AND u.[Name] = 'часть 23248'
--11.5 company (or fewer)
SELECT Surname + ' ' + p.[Name] + ' ' + Patronymic Soldier, s.[Name]
FROM Personnel p, Speciality s, Company c
WHERE SpecialityID = s.ID AND s.[Name] = 'водитель' AND p.CompanyID = c.ID AND c.[Name] = '9 рота'

/* --- 12 --- */
--12.1 quantity > 10
SELECT [Name] Unit, [Type], Quantity, Additional
FROM Unit u, Weaponry
WHERE u.ID = UnitID AND Quantity > 10 AND [Type] = 'пм'
--12.2 no such type
SELECT [Name] Unit
FROM Unit u
EXCEPT
SELECT [Name] Unit
FROM Unit u, Weaponry
WHERE u.ID = UnitID AND [Type] = 'акс-74ун'

/* --- 13 --- */
--13.1 army, max
SELECT a.[Name], COUNT(u.ID) Units
FROM Unit u, Army a, Formation f
WHERE u.FormationID = f.ID AND f.ArmyID = a.ID
GROUP BY a.[Name]
HAVING COUNT(u.ID) = (SELECT MAX(sub.Quantity)
					  FROM (SELECT COUNT(u.ID) Quantity
							FROM Unit u, Army a, Formation f
							WHERE u.FormationID = f.ID AND f.ArmyID = a.ID
							GROUP BY a.ID) sub)
--13.2 formation, min
SELECT f.[Name], COUNT(u.ID) Units
FROM Unit u, Formation f
WHERE u.FormationID = f.ID
GROUP BY f.[Name]
HAVING COUNT(u.ID) = (SELECT MIN(sub.Quantity)
					  FROM (SELECT COUNT(u.ID) Quantity
							FROM Unit u, Formation f
							WHERE u.FormationID = f.ID
							GROUP BY f.ID) sub)