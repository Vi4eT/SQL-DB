--Delete DB
EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'PolyDB'
GO
USE [master]
GO
ALTER DATABASE [PolyDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE [PolyDB]
GO


--Create DB
CREATE DATABASE [PolyDB]
GO

USE [PolyDB]
GO

CREATE TABLE Department
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
)
GO

INSERT INTO Department ([Name]) VALUES
	('Приемное'), 
	('Терапевтическое'),
	('Рентгенологическое'),
	('Хирургическое'),
	('Педиатрия'),
	('Гинекологическое'),
	('Неврологическое'),
	('Стоматологическое')
GO

CREATE TABLE Ward
(
	[ID] int PRIMARY KEY,
	[DepartmentID] tinyint NOT NULL REFERENCES Department (ID)
)
GO

CREATE TABLE Specialty
(
	[ID] tinyint PRIMARY KEY IDENTITY,
	[Name] varchar(50) NOT NULL
)
GO

INSERT INTO Specialty ([Name]) VALUES
	('Хирург'), 
	('Терапевт'),
	('Невропатолог'),
	('Окулист'),
	('Стоматолог'),
	('Рентгенолог'),
	('Педиатр'),
	('Гинеколог')
GO

CREATE TABLE Doctor
(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(50) NOT NULL,
	[SpecialtyID] tinyint NOT NULL REFERENCES Specialty (ID),
	[DepartmentID] tinyint NOT NULL REFERENCES Department (ID)
)
GO

CREATE FUNCTION checkdep(@dID int, @wID int) RETURNS bit AS
BEGIN
	DECLARE @id1 int = (SELECT DepartmentID
					    FROM Doctor
					    WHERE ID = @dID)
	DECLARE @id2 int = (SELECT DepartmentID
			            FROM Ward
			            WHERE ID = @wID)
	IF @id1 = @id2
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE DoctorWard
(
	[DoctorID] int NOT NULL REFERENCES Doctor (ID),
	[WardID] int UNIQUE NOT NULL REFERENCES Ward (ID),
	PRIMARY KEY (DoctorID, WardID),
	CONSTRAINT CK_DoctorWard_Departments CHECK (dbo.checkdep(DoctorID, WardID) = 1)
)
GO

CREATE TABLE Patient
(
	[ID] int PRIMARY KEY IDENTITY,
	[FIO] varchar(50) NOT NULL,
	[Passport] bigint UNIQUE NOT NULL CONSTRAINT CK_Patient_Passport CHECK (Passport >= 1000000000 AND Passport <= 9999999999),
	[Policy] varchar(7) UNIQUE NOT NULL CONSTRAINT CK_Patient_Policy CHECK ([Policy] LIKE '[А-Я][А-Я][0-9][0-9][0-9][0-9][А-Я]'),
	[Allergy] varchar(50) NULL
)
GO

CREATE FUNCTION ispresent(@ID int, @d date) RETURNS bit AS
BEGIN
	DECLARE @dmin date, @dend date
	SELECT @dmin = MIN(StartDate), @dend = MAX(EndDate)
	FROM PolyCard
	WHERE PatientID = @ID
	IF @dmin = @d
		RETURN 0
	IF @dend IS NULL OR @dend > @d --для каждого отдельного пациента данные вносить хронологически
		RETURN 1
	RETURN 0
END
GO

CREATE FUNCTION isallergen(@ID int, @d varchar(50)) RETURNS bit AS
BEGIN
	DECLARE @a varchar(50) = (SELECT Allergy
							  FROM Patient
							  WHERE ID = @ID)
	IF @a LIKE '%' + @d + '%'
		RETURN 1
	RETURN 0
END
GO

CREATE TABLE PolyCard
(
	[ID] int PRIMARY KEY IDENTITY,
	[PatientID] int NOT NULL REFERENCES Patient (ID),
	[WardID] int NOT NULL REFERENCES Ward (ID),
	[Symptom] varchar(50) NOT NULL,
	[Diagnosis] varchar(50) NOT NULL,
	[Drug] varchar(50) NOT NULL,
	[StartDate] date NOT NULL DEFAULT GETDATE(),
	[EndDate] date NULL,
	UNIQUE (PatientID, StartDate),
	CONSTRAINT CK_PolyCard_IsPresent CHECK (dbo.ispresent(PatientID, StartDate) = 0),
	CONSTRAINT CK_PolyCard_IsAllergen CHECK (dbo.isallergen(PatientID, Drug) = 0),
	CONSTRAINT CK_PolyCard_Dates CHECK (StartDate <= CASE WHEN EndDate IS NULL THEN StartDate ELSE EndDate END)
)
GO


--Queries
--1
CREATE PROCEDURE AVGPatientsMonth @symptom varchar(50) AS
SELECT FIO Doctor, AVG(Patients) [Average Patients/Month]
FROM Doctor d JOIN (SELECT DoctorID, [Month], SUM(Patients) Patients
					FROM DoctorWard dw JOIN (SELECT WardID, LEFT(DATETRUNC(month, StartDate), 7) [Month], COUNT(PatientID) Patients
											 FROM PolyCard
											 WHERE Symptom LIKE '%' + @symptom + '%'
											 GROUP BY WardID, DATETRUNC(month, StartDate)) s ON dw.WardID = s.WardID
					GROUP BY DoctorID, [Month]) s1 ON d.ID = s1.DoctorID
GROUP BY FIO
ORDER BY AVG(Patients) DESC
GO

--2
CREATE PROCEDURE Top10VisitCount @spec varchar(50) AS
SELECT TOP(10) p.FIO, COUNT(PatientID) Visits
FROM PolyCard pc JOIN Patient p ON pc.PatientID = p.ID
				 JOIN DoctorWard dw ON pc.WardID = dw.WardID
				 JOIN Doctor d ON dw.DoctorID = d.ID
				 JOIN Specialty s ON d.SpecialtyID = s.ID
WHERE [Name] = @spec
GROUP BY p.FIO
ORDER BY Visits DESC
GO

--3
CREATE PROCEDURE WardswithNew @days int AS
SELECT DISTINCT WardID
FROM PolyCard
WHERE EndDate IS NULL AND DATEDIFF(day, StartDate, GETDATE()) <= @days
GO