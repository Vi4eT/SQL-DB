--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'MedDB'
GO
USE [master]
GO
ALTER DATABASE [MedDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [MedDB]
GO

-- 3 --
--Create DB
CREATE DATABASE [MedDB]
GO

USE [MedDB]
GO

CREATE FUNCTION ispoly(@ID int) RETURNS bit AS
BEGIN
	RETURN (SELECT IsPoly
			FROM Hospital
			WHERE @ID = ID)
END
GO

CREATE TABLE Hospital
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[IsPoly] bit NOT NULL,
	[AttachedToID] int NULL REFERENCES Hospital
		CONSTRAINT CK_Hospital_AttachedToID CHECK (dbo.ispoly(AttachedToID) = 0),
	CONSTRAINT CK_Hospital_Poly CHECK (CASE WHEN IsPoly = 0 AND AttachedToID IS NOT NULL THEN 1 ELSE 0 END = 0)
)
GO

CREATE TABLE Building
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[HospitalID] int NOT NULL REFERENCES Hospital (ID)
		CONSTRAINT CK_Building_HospitalID CHECK (dbo.ispoly(HospitalID) = 0)
)
GO

CREATE TABLE DepartmentType
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
) 
GO

INSERT INTO DepartmentType ([Name]) VALUES
	('Приемное'), 
	('Физиотерапевтическое'),
	('Рентгенологическое'),
	('Хирургическое'),
	('Патологоанатомическое'),
	('Гинекологическое'),
	('Неврологическое'),
	('Стоматологическое')
GO

CREATE TABLE Department
(
	[ID] int PRIMARY KEY IDENTITY,
	[TypeID] tinyint NOT NULL REFERENCES DepartmentType (ID),
	[BuildingID] int NOT NULL REFERENCES Building (ID),
)
GO

CREATE TABLE Ward
(
	[ID] int PRIMARY KEY,
	[DepartmentID] int NOT NULL REFERENCES Department (ID)
)
GO

CREATE TABLE Bed
(
	[ID] int PRIMARY KEY,
	[WardID] int NOT NULL REFERENCES Ward (ID)
)
GO

CREATE TABLE Office
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[PolyID] int NOT NULL REFERENCES Hospital (ID) 
		CONSTRAINT CK_Office_PolyID CHECK (dbo.ispoly(PolyID) = 1)
)
GO

CREATE TABLE Specialty
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[IsDoctor] bit NOT NULL
)
GO

INSERT INTO Specialty ([Name], IsDoctor) VALUES
	('Хирург', 1), 
	('Терапевт', 1),
	('Невропатолог', 1),
	('Окулист', 1),
	('Стоматолог', 1),
	('Рентгенолог', 1),
	('Гинеколог', 1),
	('Медсестра', 0),
	('Санитар', 0),
	('Уборщица', 0)
GO

CREATE FUNCTION isdoctor(@ID int) RETURNS bit AS
BEGIN
	RETURN (SELECT IsDoctor
			FROM Specialty
			WHERE ID = (SELECT SpecialtyID
						FROM Employee
						WHERE @ID = ID))
END
GO

CREATE FUNCTION check_degree(@ID int, @d varchar(3)) RETURNS bit AS
BEGIN
	IF @d IS NOT NULL AND (SELECT IsDoctor
						   FROM Specialty
						   WHERE @ID = ID) = 0
		RETURN 0
	RETURN 1
END
GO

CREATE FUNCTION isallowed(@d varchar(3), @r varchar(9)) RETURNS bit AS
BEGIN
	IF (@d IS NULL AND @r IS NOT NULL) OR (@d = 'PhD' AND @r = 'Professor')
		RETURN 0
	RETURN 1
END
GO

--TODO: коэф к зп: рентгенолог, стоматолог; отпуск: рентгенолог, невропатолог?
CREATE TABLE Employee
(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(50) NOT NULL,
	[HospitalID] int NULL REFERENCES Hospital (ID) 
		CONSTRAINT CK_Employee_HospitalID CHECK (dbo.ispoly(HospitalID) = 0),
	[PolyID] int NULL REFERENCES Hospital (ID) 
		CONSTRAINT CK_Employee_PolyID CHECK (dbo.ispoly(PolyID) = 1),
	[SpecialtyID] tinyint NOT NULL REFERENCES Specialty (ID),
	[Degree] varchar(3) NULL CONSTRAINT CK_Employee_Degree CHECK ([Degree] IN ('PhD', 'MD')),
	[Rank] varchar(9) NULL CONSTRAINT CK_Employee_Rank CHECK ([Rank] IN ('Associate', 'Professor')),
	[Experience] int NOT NULL CONSTRAINT CK_Employee_Experience CHECK (Experience >= 0),
	[Salary] money NOT NULL CONSTRAINT CK_Employee_Salary CHECK (Salary > 0),
	CONSTRAINT CK_Employee_Degree_Doctor CHECK (dbo.check_degree(SpecialtyID, Degree) = 1),
	CONSTRAINT CK_Employee_Rank_Degree CHECK (dbo.isallowed(Degree, [Rank]) = 1),
	CONSTRAINT CK_Employee_Clinics CHECK (CASE WHEN (HospitalID IS NULL AND PolyID IS NULL) 
		OR (dbo.isdoctor(ID) = 0 AND HospitalID IS NOT NULL AND PolyID IS NOT NULL) THEN 0 ELSE 1 END = 1)
)
GO

CREATE FUNCTION isranked(@ID int) RETURNS bit AS
BEGIN
	IF (SELECT [Rank]
		FROM Employee
		WHERE @ID = ID) IS NULL
		RETURN 0
	RETURN 1
END
GO

CREATE TABLE RankedConsult
(
	[EmployeeID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_RankedConsult_EmployeeID CHECK (dbo.isranked(EmployeeID) = 1),
	[HospitalID] int NOT NULL REFERENCES Hospital (ID),
	PRIMARY KEY (EmployeeID, HospitalID)
)
GO

CREATE TABLE LabType
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(20) NOT NULL
) 
GO

INSERT INTO LabType ([Name]) VALUES
	('Биохим'), 
	('Физио'),
	('Хим'),
	('Биохим + Физио'),
	('Биохим + Хим'),
	('Физио + Хим'),
	('Биохим + Физио + Хим')
GO

CREATE TABLE Lab
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL,
	[TypeID] tinyint NOT NULL REFERENCES LabType (ID)
)
GO

CREATE TABLE LabHospital
(
	[LabID] int NOT NULL REFERENCES Lab (ID),
	[HospitalID] int NOT NULL REFERENCES Hospital (ID),
	PRIMARY KEY (LabID, HospitalID)
)
GO

CREATE TABLE ResearchType
(
	[ID] int PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
) 
GO

CREATE FUNCTION check_contract(@l int, @h int) RETURNS bit AS
BEGIN
	IF @h IN (SELECT HospitalID
			  FROM LabHospital
			  WHERE @l = LabID)
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE Research
(
	[ID] int PRIMARY KEY IDENTITY,
	[TypeID] int NOT NULL REFERENCES ResearchType (ID),
	[LabID] int NOT NULL REFERENCES Lab (ID),
	[HospitalID] int NOT NULL REFERENCES Hospital (ID),
	[Date] date NOT NULL,
	CONSTRAINT CK_Research_Check_Contract CHECK (dbo.check_contract(LabID, HospitalID) = 1)
)
GO

CREATE TABLE Patient
(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(50) NOT NULL
)
GO

--TODO: ограничение по месту работы? по текущей дате
CREATE TABLE PolyclinicCard
(
	[ID] int PRIMARY KEY IDENTITY,
	[PatientID] int NOT NULL REFERENCES Patient (ID),
	[OfficeID] int NOT NULL REFERENCES Office (ID),
	[DoctorID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_PolyclinicCard_DoctorID CHECK (dbo.isdoctor(DoctorID) = 1),
	[Date] date NOT NULL
)
GO

--isinhospital и isfreebed не работают на новых записях без EndDate, не юзать в таблице
/*CREATE FUNCTION isinhospital(@ID int) RETURNS bit AS
BEGIN
	DECLARE @d1 date = (SELECT MAX(StartDate)
					   FROM HospitalCard
					   WHERE @ID = PatientID)
	IF @d1 IS NULL
		RETURN 0
	DECLARE @d2 date = (SELECT MAX(EndDate)
						FROM HospitalCard
						WHERE @ID = PatientID)
	IF @d2 IS NULL OR @d2 < @d1
		RETURN 1
	RETURN 0
END
GO*/

CREATE FUNCTION isfreebed(@ID int) RETURNS bit AS
BEGIN
	DECLARE @d date = (SELECT MAX(StartDate)
					   FROM HospitalCard
					   WHERE @ID = BedID)
	IF @d IS NULL 
		RETURN 1
	ELSE IF (SELECT EndDate
			 FROM HospitalCard
			 WHERE @ID = BedID AND StartDate = @d) IS NULL
		RETURN 0
	RETURN 1
END
GO

--TODO: ограничение по месту работы? по текущей дате, по температуре, типы статусов?
CREATE TABLE HospitalCard
(
	[ID] int PRIMARY KEY IDENTITY,
	[PatientID] int NOT NULL REFERENCES Patient (ID),
	[BedID] int NOT NULL REFERENCES Bed (ID),
	[DoctorID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_HospitalCard_DoctorID CHECK (dbo.isdoctor(DoctorID) = 1),
	[StartDate] date NOT NULL,
	[EndDate] date NULL,
	[Status] varchar(50) NULL,
	[Temperature] real NULL,
	--CONSTRAINT CK_HospitalCard_IsInHospital CHECK (dbo.isinhospital(PatientID) = 0),
	--CONSTRAINT CK_HospitalCard_IsFreeBed CHECK (dbo.isfreebed(BedID) = 1),
	CONSTRAINT CK_HospitalCard_Dates CHECK (StartDate <= CASE WHEN EndDate IS NULL THEN StartDate ELSE EndDate END)
)
GO

CREATE FUNCTION check_operation(@ID int) RETURNS bit AS
BEGIN
	IF (SELECT [Name]
		FROM Specialty
		WHERE ID = (SELECT SpecialtyID
					FROM Employee
					WHERE @ID = ID)) IN ('Хирург', 'Стоматолог', 'Гинеколог')
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE Operation
(
	[ID] int PRIMARY KEY IDENTITY,
	[PatientID] int NOT NULL REFERENCES Patient (ID),
	[HospitalID] int NOT NULL REFERENCES Hospital (ID),
	[DoctorID] int NOT NULL REFERENCES Employee (ID)
		CONSTRAINT CK_Operation_DoctorID CHECK (dbo.check_operation(DoctorID) = 1),
	[Date] date NOT NULL,
	[IsLethal] bit NOT NULL
)
GO


--Queries
--1 
--больница
DECLARE @s varchar(20) = 'хирург', 
		@h varchar(50) = 'Городская многопрофильная больница №2'
SELECT FIO, Degree, [Rank], Experience, Salary
FROM Employee e JOIN Hospital h ON e.HospitalID = h.ID
				JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = @s AND h.[Name] = @h
UNION
SELECT FIO, Degree, [Rank], Experience, Salary
FROM Employee e JOIN RankedConsult rc ON e.ID = rc.EmployeeID
				JOIN Hospital h ON rc.HospitalID = h.ID
				JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = @s AND h.[Name] = @h
GO
--все
SELECT FIO, Degree, [Rank], Experience, Salary
FROM Employee e JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'хирург'

--2 
--поликлиника
SELECT FIO, Experience, Salary
FROM Employee e JOIN Hospital h ON e.PolyID = h.ID
				JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'санитар' AND h.[Name] = 'Поликлиника №49'
--все
SELECT FIO, Experience, Salary
FROM Employee e JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'санитар'

--3 
--больница
SELECT FIO, COUNT(DoctorID) Operations, Degree, [Rank], Experience, Salary
FROM Employee e JOIN Specialty s ON e.SpecialtyID = s.ID
				JOIN Operation o ON o.DoctorID = e.ID
				JOIN Hospital h ON e.HospitalID = h.ID
WHERE s.[Name] = 'стоматолог' AND h.[Name] = 'Городская многопрофильная больница №2'
GROUP BY FIO, Degree, [Rank], Experience, Salary
HAVING COUNT(DoctorID) > 1
--все
SELECT FIO, COUNT(DoctorID) Operations, Degree, [Rank], Experience, Salary
FROM Employee e JOIN Specialty s ON e.SpecialtyID = s.ID
				JOIN Operation o ON o.DoctorID = e.ID
WHERE s.[Name] = 'стоматолог'
GROUP BY FIO, Degree, [Rank], Experience, Salary
HAVING COUNT(DoctorID) > 1

--4 
--больница
DECLARE @s varchar(20) = 'невропатолог', 
		@h varchar(50) = 'Елизаветинская больница'
SELECT FIO, Degree, [Rank], Experience, Salary
FROM Employee e JOIN Hospital h ON e.HospitalID = h.ID
				JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = @s AND h.[Name] = @h AND Experience >= 10
UNION
SELECT FIO, Degree, [Rank], Experience, Salary
FROM Employee e JOIN RankedConsult rc ON e.ID = rc.EmployeeID
				JOIN Hospital h ON rc.HospitalID = h.ID
				JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = @s AND h.[Name] = @h AND Experience >= 10
GO
--все
SELECT FIO, Degree, [Rank], Experience, Salary
FROM Employee e JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'невропатолог' AND Experience >= 10

--5 
--поликлиника, доктор наук
DECLARE @s varchar(20) = 'рентгенолог', 
		@h varchar(50) = 'Городская поликлиника №14',
		@d varchar(3) = 'MD'
SELECT FIO, [Rank], Experience, Salary
FROM Employee e JOIN Hospital h ON e.PolyID = h.ID
				JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = @s AND h.[Name] = @h AND Degree = @d
UNION
SELECT FIO, [Rank], Experience, Salary
FROM Employee e JOIN RankedConsult rc ON e.ID = rc.EmployeeID
				JOIN Hospital h ON rc.HospitalID = h.ID
				JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = @s AND h.[Name] = @h AND Degree = @d
GO
--все доценты
SELECT FIO, Degree, Experience, Salary
FROM Employee e JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'рентгенолог' AND [Rank] = 'Associate'

--6 
--палата
SELECT p.FIO Patient, b.ID Bed, e.FIO Doctor, StartDate, [Status], Temperature
FROM HospitalCard hc JOIN Patient p ON hc.PatientID = p.ID
					 JOIN Bed b ON hc.BedID = b.ID
					 JOIN Employee e ON hc.DoctorID = e.ID
WHERE WardID = 6 AND EndDate IS NULL
--отделение
SELECT p.FIO Patient, b.ID Bed, e.FIO Doctor, StartDate, [Status], Temperature
FROM HospitalCard hc JOIN Patient p ON hc.PatientID = p.ID
					 JOIN Bed b ON hc.BedID = b.ID
					 JOIN Ward w ON b.WardID = w.ID
					 JOIN Department d ON w.DepartmentID = d.ID
					 JOIN DepartmentType dt ON d.TypeID = dt.ID
					 JOIN Employee e ON hc.DoctorID = e.ID
WHERE dt.[Name] = 'приёмное' AND EndDate IS NULL
--больница
SELECT DISTINCT p.FIO Patient, b.ID Bed, e.FIO Doctor, StartDate, [Status], Temperature
FROM HospitalCard hc JOIN Patient p ON hc.PatientID = p.ID
					 JOIN Bed b ON hc.BedID = b.ID
					 JOIN Ward w ON b.WardID = w.ID
					 JOIN Department d ON w.DepartmentID = d.ID
					 JOIN Building bd ON d.BuildingID = bd.HospitalID
					 JOIN Hospital h ON bd.HospitalID = h.ID
					 JOIN Employee e ON hc.DoctorID = e.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2' AND EndDate IS NULL

--7 
--врач
SELECT p.FIO Patient, StartDate, EndDate
FROM HospitalCard hc JOIN Patient p ON hc.PatientID = p.ID
					 JOIN Employee e ON hc.DoctorID = e.ID
WHERE e.FIO = 'Иванов Иван Иванович' AND StartDate >= '20200101' AND EndDate <= '20210101'
--больница
SELECT DISTINCT p.FIO Patient, StartDate, EndDate
FROM HospitalCard hc JOIN Patient p ON hc.PatientID = p.ID
					 JOIN Bed b ON hc.BedID = b.ID
					 JOIN Ward w ON b.WardID = w.ID
					 JOIN Department d ON w.DepartmentID = d.ID
					 JOIN Building bd ON d.BuildingID = bd.HospitalID
					 JOIN Hospital h ON bd.HospitalID = h.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2' AND StartDate >= '20200101' AND EndDate <= '20210101'

--8
SELECT p.FIO Patient, e.FIO Doctor, [Date]
FROM PolyclinicCard pc JOIN Office o ON pc.OfficeID = o.ID
					   JOIN	Hospital h ON o.PolyID = h.ID
					   JOIN Patient p ON pc.PatientID = p.ID
					   JOIN Employee e ON pc.DoctorID = e.ID
					   JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'окулист' AND h.[Name] = 'Поликлиника №49'

--9
--палаты больницы
SELECT COUNT(w.ID) [Wards Count]
FROM Ward w JOIN Department d ON w.DepartmentID = d.ID
			JOIN Building b ON d.BuildingID = b.ID
			JOIN Hospital h ON b.HospitalID = h.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2'
--палаты больницы по отделениям
SELECT dt.[Name], COUNT(w.ID) [Wards Count]
FROM Ward w JOIN Department d ON w.DepartmentID = d.ID
			JOIN Building b ON d.BuildingID = b.ID
			JOIN Hospital h ON b.HospitalID = h.ID
			JOIN DepartmentType dt ON d.TypeID = dt.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2'
GROUP BY dt.[Name]
--места больницы
SELECT COUNT(Bed.ID) [Beds Count]
FROM Bed JOIN Ward w ON Bed.WardID = w.ID
		 JOIN Department d ON w.DepartmentID = d.ID
		 JOIN Building b ON d.BuildingID = b.ID
		 JOIN Hospital h ON b.HospitalID = h.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2'
--места больницы по отделениям
SELECT dt.[Name], COUNT(Bed.ID) [Beds Count]
FROM Bed JOIN Ward w ON Bed.WardID = w.ID
		 JOIN Department d ON w.DepartmentID = d.ID
		 JOIN Building b ON d.BuildingID = b.ID
		 JOIN Hospital h ON b.HospitalID = h.ID
		 JOIN DepartmentType dt ON d.TypeID = dt.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2'
GROUP BY dt.[Name]
--число свободных мест по отделениям
SELECT dt.[Name], COUNT(Bed.ID) [Free Beds Count]
FROM Bed JOIN Ward w ON Bed.WardID = w.ID
		 JOIN Department d ON w.DepartmentID = d.ID
		 JOIN Building b ON d.BuildingID = b.ID
		 JOIN Hospital h ON b.HospitalID = h.ID
		 JOIN DepartmentType dt ON d.TypeID = dt.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2' AND dbo.isfreebed(Bed.ID) = 1
GROUP BY dt.[Name]
--число полностью свободных палат
DECLARE @h varchar(50) = 'Городская многопрофильная больница №2'
SELECT COUNT(s2.ID) [Free Wards]
FROM (SELECT w.ID, COUNT(Bed.ID) [Free Beds Count]
	  FROM Bed JOIN Ward w ON Bed.WardID = w.ID
			   JOIN Department d ON w.DepartmentID = d.ID
			   JOIN Building b ON d.BuildingID = b.ID
			   JOIN Hospital h ON b.HospitalID = h.ID
			   JOIN DepartmentType dt ON d.TypeID = dt.ID
	  WHERE h.[Name] = @h AND dbo.isfreebed(Bed.ID) = 1
	  GROUP BY w.ID) s1 
	JOIN (SELECT w.ID, COUNT(Bed.ID) [Beds Count]
		  FROM Bed JOIN Ward w ON Bed.WardID = w.ID
				   JOIN Department d ON w.DepartmentID = d.ID
				   JOIN Building b ON d.BuildingID = b.ID
				   JOIN Hospital h ON b.HospitalID = h.ID
				   JOIN DepartmentType dt ON d.TypeID = dt.ID
		  WHERE h.[Name] = @h
		  GROUP BY w.ID) s2 ON s1.ID = s2.ID
WHERE [Beds Count] - [Free Beds Count] = 0
GO

--10
--число кабинетов
SELECT COUNT(o.ID) [Office Count]
FROM Office o JOIN Hospital h ON o.PolyID = h.ID
WHERE h.[Name] = 'Поликлиника №49'
--число посещений
SELECT o.[Name] Office, COUNT(OfficeID) [Visit Count]
FROM Office o JOIN Hospital h ON o.PolyID = h.ID
			  JOIN PolyclinicCard pc ON pc.OfficeID = o.ID
WHERE h.[Name] = 'Городская поликлиника №14' AND [Date] BETWEEN '20200101' AND '20210101'
GROUP BY o.[Name]

--11 
--врач
DECLARE @d1 date = '20200101', @d2 date = '20210101'
SELECT COUNT(DoctorID) / CAST(DATEDIFF(day, @d1, @d2) AS real) [Average Patient Number]
FROM PolyclinicCard pc JOIN Employee e ON pc.DoctorID = e.ID
WHERE e.FIO = 'Иванов Иван Иванович' AND [Date] BETWEEN @d1 AND @d2
GO
--поликлиника
DECLARE @d1 date = '20200101', @d2 date = '20210101'
SELECT COUNT(DoctorID) / CAST(DATEDIFF(day, @d1, @d2) AS real) [Average Patient Number]
FROM PolyclinicCard pc JOIN Employee e ON pc.DoctorID = e.ID
					   JOIN Hospital h ON e.PolyID = h.ID
WHERE h.[Name] = 'Городская поликлиника №14' AND [Date] BETWEEN @d1 AND @d2
GO
--специальность
DECLARE @d1 date = '20200101', @d2 date = '20210101'
SELECT COUNT(DoctorID) / CAST(DATEDIFF(day, @d1, @d2) AS real) [Average Patient Number]
FROM PolyclinicCard pc JOIN Employee e ON pc.DoctorID = e.ID
					   JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'хирург' AND [Date] BETWEEN @d1 AND @d2
GO

--12
--врач
SELECT COUNT(DoctorID) [Current Patient Number]
FROM HospitalCard hc JOIN Employee e ON hc.DoctorID = e.ID
WHERE e.FIO = 'Богомолова Мирослава Матвеевна' AND EndDate IS NULL
--больница
SELECT FIO, COUNT(DoctorID) [Current Patient Number]
FROM HospitalCard hc JOIN Employee e ON hc.DoctorID = e.ID
					 JOIN Hospital h ON e.HospitalID = h.ID
WHERE h.[Name] = 'Городская многопрофильная больница №2' AND EndDate IS NULL
GROUP BY FIO
--специальность
SELECT FIO, COUNT(DoctorID) [Current Patient Number]
FROM HospitalCard hc JOIN Employee e ON hc.DoctorID = e.ID
					 JOIN Specialty s ON e.SpecialtyID = s.ID
WHERE s.[Name] = 'стоматолог' AND EndDate IS NULL
GROUP BY FIO

--13 
--больница, поликлиника
SELECT p.FIO Patient, e.FIO Doctor, [Date]
FROM Operation o JOIN Hospital h ON o.HospitalID = h.ID
				 JOIN Patient p ON o.PatientID = p.ID
				 JOIN Employee e ON o.DoctorID = e.ID
WHERE h.[Name] = 'Городская поликлиника №14' AND [Date] BETWEEN '20200101' AND '20210101'
--доктор
SELECT p.FIO Patient, [Date]
FROM Operation o JOIN Patient p ON o.PatientID = p.ID
				 JOIN Employee e ON o.DoctorID = e.ID
WHERE e.FIO = 'Богданов Иван Максимович' AND [Date] BETWEEN '20200101' AND '20210101'

--14 
--лаба
DECLARE @d1 date = '20200101', @d2 date = '20210101'
SELECT COUNT(LabID) / CAST(DATEDIFF(day, @d1, @d2) AS real) [Average Research Number]
FROM Research r JOIN Lab l ON r.LabID = l.ID
WHERE l.[Name] = 'МедЛаб' AND [Date] BETWEEN @d1 AND @d2
GO
--больница, поликлиника
DECLARE @d1 date = '20200101', @d2 date = '20210101'
SELECT COUNT(LabID) / CAST(DATEDIFF(day, @d1, @d2) AS real) [Average Research Number]
FROM Research r JOIN Hospital h ON r.HospitalID = h.ID
WHERE h.[Name] = 'Поликлиника №49' AND [Date] BETWEEN @d1 AND @d2
GO
--все
DECLARE @d1 date = '20200101', @d2 date = '20210101'
SELECT COUNT(LabID) / CAST(DATEDIFF(day, @d1, @d2) AS real) [Average Research Number]
FROM Research
WHERE [Date] BETWEEN @d1 AND @d2
GO